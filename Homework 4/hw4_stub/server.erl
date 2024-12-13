-module(server).

-export([start_server/0]).

-include_lib("./defs.hrl").

-spec start_server() -> _.
-spec loop(_State) -> _.
-spec do_join(_ChatName, _ClientPID, _Ref, _State) -> _.
-spec do_leave(_ChatName, _ClientPID, _Ref, _State) -> _.
-spec do_new_nick(_State, _Ref, _ClientPID, _NewNick) -> _.
-spec do_client_quit(_State, _Ref, _ClientPID) -> _NewState.

%%Alisha Patel

start_server() ->
    catch(unregister(server)),
    register(server, self()),
    case whereis(testsuite) of
	undefined -> ok;
	TestSuitePID -> TestSuitePID!{server_up, self()}
    end,
    loop(
      #serv_st{
	 nicks = maps:new(), %% nickname map. client_pid => "nickname"
	 registrations = maps:new(), %% registration map. "chat_name" => [client_pids]
	 chatrooms = maps:new() %% chatroom map. "chat_name" => chat_pid
	}
     ).

loop(State) ->
    receive 
	%% initial connection
	{ClientPID, connect, ClientNick} ->
	    NewState =
		#serv_st{
		   nicks = maps:put(ClientPID, ClientNick, State#serv_st.nicks),
		   registrations = State#serv_st.registrations,
		   chatrooms = State#serv_st.chatrooms
		  },
	    loop(NewState);
	%% client requests to join a chat
	{ClientPID, Ref, join, ChatName} ->
	    NewState = do_join(ChatName, ClientPID, Ref, State),
	    loop(NewState);
	%% client requests to join a chat
	{ClientPID, Ref, leave, ChatName} ->
	    NewState = do_leave(ChatName, ClientPID, Ref, State),
	    loop(NewState);
	%% client requests to register a new nickname
	{ClientPID, Ref, nick, NewNick} ->
	    NewState = do_new_nick(State, Ref, ClientPID, NewNick),
	    loop(NewState);
	%% client requests to quit
	{ClientPID, Ref, quit} ->
	    NewState = do_client_quit(State, Ref, ClientPID),
	    loop(NewState);
	{TEST_PID, get_state} ->
	    TEST_PID!{get_state, State},
	    loop(State)
    end.

%% executes join protocol from server perspective
do_join(ChatName, ClientPID, Ref, State) ->
    case maps:get(ChatName, State#serv_st.chatrooms, ChatName) of
		ChatName ->
			%% If chatroom does not exist, create a new chatroom
			ChatRoomPID = spawn(chatroom, start_chatroom, [ChatName]),
			%%NewChatRooms = maps:put(ChatName, NewChatRoomPID, State#serv_st.chatrooms),
			%%NewRegistrations = maps:put(ChatName, [ClientPID], State#serv_st.registrations),
			NewState = State#serv_st{
				chatrooms = maps:put(ChatName, ChatRoomPID, State#serv_st.chatrooms),
				registrations = maps:put(ChatName, [], State#serv_st.registrations)
			},
			do_join(ChatName, ClientPID, Ref, NewState);
		ChatRoomPID ->
			%% If chatroom exists:
			ClientNick = maps:get(ClientPID, State#serv_st.nicks),
			ChatRoomPID!{self(), Ref, register, ClientPID, ClientNick},			
			%% Update registrations by adding the client
			State#serv_st{registrations=maps:put(ChatName, maps:get(ChatName, State#serv_st.registrations) ++ [ClientPID], State#serv_st.registrations)}
	end.

%% executes leave protocol from server perspective
do_leave(ChatName, ClientPID, Ref, State) ->
    case maps:find(ChatName, State#serv_st.chatrooms) of
		{ok, ChatPID} ->
			%% Remove client from the chatroom's registration
			Registrations = State#serv_st.registrations,
			UpdatedRegistrations = maps:put(ChatName, lists:delete(ClientPID, maps:get(ChatName, Registrations)), Registrations),
			%% Unregister client and acknowledge leave
			ChatPID!{self(), Ref, unregister, ClientPID},
			ClientPID!{self(), Ref, ack_leave},

			%% Return updated state
			State#serv_st{registrations = UpdatedRegistrations};

		error ->
			%% Client not in chatroom, send error
			ClientPID!{self(), Ref, err_not_in_chatroom},
			State
	end.

%% executes new nickname protocol from server perspective
do_new_nick(State, Ref, ClientPID, NewNick) ->
    case lists:member(NewNick, maps:values(State#serv_st.nicks)) of
		true ->
			%% If nickname is already taken, send error
			ClientPID!{self(), Ref, err_nick_used},
			State;

		false ->
			Helper = fun(_X,Y) -> lists:member(ClientPID,Y) end,
			ClientChatrooms = maps:filter(Helper, State#serv_st.registrations),
			Update = fun(N) -> ChatPID = maps:get(N,State#serv_st.chatrooms), 
							ChatPID!{self(), Ref, update_nick, ClientPID, maps:values(State#serv_st.nicks)} 
							end,
			lists:foreach(Update, maps:keys(ClientChatrooms)),

			%% Send the new nickname to all relevant chatrooms
			%ChatroomsWithClient = maps:filter(
			%	fun(_, PIDs) -> lists:member(ClientPID, PIDs) end,
			%	State#serv_st.registrations
			%),
			%lists:foreach(
			%	fun({_, ChatPID}) ->
			%		ChatPID ! {self(), Ref, update_nick, ClientPID, NewNick}
			%	end, maps:to_list(ChatroomsWithClient)
			%),
			%% Send success response to client
			ClientPID!{self(), Ref, ok_nick},
			%% Return updated state
			State#serv_st{nicks = maps:update(ClientPID, NewNick, State#serv_st.nicks)}
	end.


%% executes client quit protocol from server perspective
do_client_quit(State, Ref, ClientPID) ->
	%% Identify chatrooms where the client is registered
    Pred = fun(_K, V) -> lists:member(ClientPID, V) end,
    Chatrooms = maps:filter(Pred, State#serv_st.registrations),

    %% Notify each chatroom that the client is leaving
    NotifyChatroom = fun(Key) ->
        case maps:find(Key, State#serv_st.chatrooms) of
            {ok, PID} ->
                PID ! {self(), Ref, unregister, ClientPID};
            error ->
                io:format("Chatroom not found")
        end
    end,
    lists:foreach(NotifyChatroom, maps:keys(Chatrooms)),

    %% Remove the client from all chat registrations
    UpdatedRegistrations =
        maps:map(fun(_, V) ->
                     case lists:member(ClientPID, V) of
                         true -> lists:delete(ClientPID, V);
                         _ -> V
                     end
                 end, State#serv_st.registrations),

    %% Notify the client of successful quit
    ClientPID!{self(), Ref, ack_quit},

    %% Update and return the server state
    NewState = #serv_st{
        nicks = maps:remove(ClientPID, State#serv_st.nicks),
        registrations = UpdatedRegistrations,
        chatrooms = State#serv_st.chatrooms
    },
    NewState.

	
