-module(shipping).
-compile(export_all).
-include_lib("./shipping.hrl").
%Alisha Patel
%I pledge my honor that I have abided by the Stevens Honor System. 

get_ship(Shipping_State, Ship_ID) ->
    Ship = lists:keyfind(Ship_ID, #ship.id, Shipping_State#shipping_state.ships),
    case Ship of
        false -> throw(error);
        _ -> Ship
    end.

get_container(Shipping_State, Container_ID) ->
    Containers = Shipping_State#shipping_state.containers,
    Container = lists:keyfind(Container_ID, #container.id, Containers),
    case Container of
        false -> throw(error);
        _ -> Container
    end.

get_port(Shipping_State, Port_ID) ->
    Ports = Shipping_State#shipping_state.ports,
    Port = lists:keyfind(Port_ID, #port.id, Ports),
    case Port of
        false -> throw(error);
        _ -> Port
    end.

get_occupied_docks(Shipping_State, Port_ID) ->
    DockLocations = Shipping_State#shipping_state.ship_locations,
    lists:foldl(fun({P, Dock, _}, Occupied) ->
                    if P =:= Port_ID -> [Dock | Occupied];
                       true -> Occupied
                    end
                end, [], DockLocations).

get_ship_location(Shipping_State, Ship_ID) ->
    Locations = Shipping_State#shipping_state.ship_locations,
    case lists:keyfind(Ship_ID, 3, Locations) of
        false -> throw(error);
        {Port_ID, Dock_ID, _} -> {Port_ID, Dock_ID}
    end.

%find all containers in shipping state, and then find each cont's weight -> add them up
get_container_weight(Shipping_State, Container_IDs) ->
    Containers = Shipping_State#shipping_state.containers,
    % Ensure all Container_IDs are valid before proceeding
    Missing_IDs = [ID || ID <- Container_IDs, not lists:member(ID, [Container#container.id || Container <- Containers])],
    
    % If there are any missing container IDs, throw an error
    case Missing_IDs of
        [] -> ContWeight = [Container#container.weight || Container <- Containers, 
                          lists:member(Container#container.id, Container_IDs)],
            lists:sum(ContWeight);
        _ -> throw(error)
    end.

%list all the ships in the ship_inventory and use cont weight function
get_ship_weight(Shipping_State, Ship_ID) ->
    case maps:find(Ship_ID, Shipping_State#shipping_state.ship_inventory) of
        {ok, Container_IDs} -> get_container_weight(Shipping_State, Container_IDs);
        _ -> throw(error)
    end.

%ship needs to have enough capacity, containers on same port, containers are not already on
%get ship located and inventory for ship and port
%check the total number containers on same port that are not loaded
%update port and ship inventory 
load_ship(Shipping_State, Ship_ID, Container_IDs) ->
    Ship = get_ship(Shipping_State, Ship_ID),
    {Port_ID, _Dock} = get_ship_location(Shipping_State, Ship_ID),
    ShipInventory = Shipping_State#shipping_state.ship_inventory,
    PortInventory = Shipping_State#shipping_state.port_inventory,

    {ok, Port_Containers} = maps:find(Port_ID, PortInventory),
    {ok, Ship_Containers} = maps:find(Ship_ID, ShipInventory),
    NewContainerCount = lists:flatlength(Container_IDs ++ Ship_Containers),
    
    CapacityExceeded = NewContainerCount > Ship#ship.container_cap,
    ContainersNotInPort = not is_sublist(Port_Containers, Container_IDs),
    ContainersAlreadyLoaded = lists:any(fun (C) -> lists:member(C, Ship_Containers) end, Container_IDs),
    if CapacityExceeded or ContainersNotInPort or ContainersAlreadyLoaded ->
        throw(error);
    true ->
        NewPortInventory = maps:put(Port_ID, Port_Containers -- Container_IDs, PortInventory),
        NewShipInventory = maps:put(Ship_ID, Ship_Containers ++ Container_IDs, ShipInventory),
        {ok, Shipping_State#shipping_state{port_inventory = NewPortInventory, ship_inventory = NewShipInventory}}
    end.
    
%port have enough space to load
%get list of all containers on specified ship
%use unload_ship 
unload_ship_all(Shipping_State, Ship_ID) ->
    ShipInventory = Shipping_State#shipping_state.ship_inventory,
    case maps:find(Ship_ID, ShipInventory) of
        {ok, Ship_Containers} -> 
            unload_ship(Shipping_State, Ship_ID, Ship_Containers);
        error ->
            throw(error)
    end.

%port needs to have enough space
%verfify that containers on the same port are not already loaded
%transfer from ship inventory to port inventory
unload_ship(Shipping_State, Ship_ID, Container_IDs) ->
    %Ship = get_ship(Shipping_State, Ship_ID),
    {Port_ID, _Dock} = get_ship_location(Shipping_State, Ship_ID),
    ShipInventory = Shipping_State#shipping_state.ship_inventory,
    PortInventory = Shipping_State#shipping_state.port_inventory,

    {ok, Ship_Containers} = maps:find(Ship_ID, ShipInventory),
    {ok, Port_Containers} = maps:find(Port_ID, PortInventory),
    Port = get_port(Shipping_State, Port_ID),

    NewContainerCount = lists:flatlength(Container_IDs ++ Port_Containers),
    CapacityExceeded = NewContainerCount > Port#port.container_cap,
    ContainersAlreadyAtPort = lists:any(fun (C) -> lists:member(C, Port_Containers) end, Container_IDs),
    ContainersNotOnShip = not is_sublist(Ship_Containers, Container_IDs),

    if CapacityExceeded orelse ContainersAlreadyAtPort orelse ContainersNotOnShip ->
        throw(error);
    true ->
        NewPortInventory = maps:put(Port_ID, Port_Containers ++ Container_IDs, PortInventory),
        NewShipInventory = maps:put(Ship_ID, Ship_Containers -- Container_IDs, ShipInventory),
        {ok, Shipping_State#shipping_state{port_inventory = NewPortInventory, ship_inventory = NewShipInventory}}
    end.

%check of dock is inoccupied
%verify that port and sock are not the same location
%update ship location
set_sail(Shipping_State, Ship_ID, {Port_ID, Dock}) ->
    {CurrentPort, _CurrentDock} = get_ship_location(Shipping_State, Ship_ID),
    ShipLocations = Shipping_State#shipping_state.ship_locations,

    MovingToSamePort = CurrentPort == Port_ID,
    DockOccupied = lists:any(fun ({P, D, _S}) -> {P, D} == {Port_ID, Dock} end, ShipLocations),

    if MovingToSamePort orelse DockOccupied ->
        throw(error);
    true ->
        UpdatedLocations = [{P, D, S} || {P, D, S} <- ShipLocations, S =/= Ship_ID] ++ [{Port_ID, Dock, Ship_ID}],
        {ok, Shipping_State#shipping_state{ship_locations = UpdatedLocations}}
    end.




%% Determines whether all of the elements of Sub_List are also elements of Target_List
%% @returns true is all elements of Sub_List are members of Target_List; false otherwise
is_sublist(Target_List, Sub_List) ->
    lists:all(fun (Elem) -> lists:member(Elem, Target_List) end, Sub_List).




%% Prints out the current shipping state in a more friendly format
print_state(Shipping_State) ->
    io:format("--Ships--~n"),
    _ = print_ships(Shipping_State#shipping_state.ships, Shipping_State#shipping_state.ship_locations, Shipping_State#shipping_state.ship_inventory, Shipping_State#shipping_state.ports),
    io:format("--Ports--~n"),
    _ = print_ports(Shipping_State#shipping_state.ports, Shipping_State#shipping_state.port_inventory).


%% helper function for print_ships
get_port_helper([], _Port_ID) -> error;
get_port_helper([ Port = #port{id = Port_ID} | _ ], Port_ID) -> Port;
get_port_helper( [_ | Other_Ports ], Port_ID) -> get_port_helper(Other_Ports, Port_ID).


print_ships(Ships, Locations, Inventory, Ports) ->
    case Ships of
        [] ->
            ok;
        [Ship | Other_Ships] ->
            {Port_ID, Dock_ID, _} = lists:keyfind(Ship#ship.id, 3, Locations),
            Port = get_port_helper(Ports, Port_ID),
            {ok, Ship_Inventory} = maps:find(Ship#ship.id, Inventory),
            io:format("Name: ~s(#~w)    Location: Port ~s, Dock ~s    Inventory: ~w~n", [Ship#ship.name, Ship#ship.id, Port#port.name, Dock_ID, Ship_Inventory]),
            print_ships(Other_Ships, Locations, Inventory, Ports)
    end.

print_containers(Containers) ->
    io:format("~w~n", [Containers]).

print_ports(Ports, Inventory) ->
    case Ports of
        [] ->
            ok;
        [Port | Other_Ports] ->
            {ok, Port_Inventory} = maps:find(Port#port.id, Inventory),
            io:format("Name: ~s(#~w)    Docks: ~w    Inventory: ~w~n", [Port#port.name, Port#port.id, Port#port.docks, Port_Inventory]),
            print_ports(Other_Ports, Inventory)
    end.
%% This functions sets up an initial state for this shipping simulation. You can add, remove, or modidfy any of this content. This is provided to you to save some time.
%% @returns {ok, shipping_state} where shipping_state is a shipping_state record with all the initial content.
shipco() ->
    Ships = [#ship{id=1,name="Santa Maria",container_cap=20},
              #ship{id=2,name="Nina",container_cap=20},
              #ship{id=3,name="Pinta",container_cap=20},
              #ship{id=4,name="SS Minnow",container_cap=20},
              #ship{id=5,name="Sir Leaks-A-Lot",container_cap=20}
             ],
    Containers = [
                  #container{id=1,weight=200},
                  #container{id=2,weight=215},
                  #container{id=3,weight=131},
                  #container{id=4,weight=62},
                  #container{id=5,weight=112},
                  #container{id=6,weight=217},
                  #container{id=7,weight=61},
                  #container{id=8,weight=99},
                  #container{id=9,weight=82},
                  #container{id=10,weight=185},
                  #container{id=11,weight=282},
                  #container{id=12,weight=312},
                  #container{id=13,weight=283},
                  #container{id=14,weight=331},
                  #container{id=15,weight=136},
                  #container{id=16,weight=200},
                  #container{id=17,weight=215},
                  #container{id=18,weight=131},
                  #container{id=19,weight=62},
                  #container{id=20,weight=112},
                  #container{id=21,weight=217},
                  #container{id=22,weight=61},
                  #container{id=23,weight=99},
                  #container{id=24,weight=82},
                  #container{id=25,weight=185},
                  #container{id=26,weight=282},
                  #container{id=27,weight=312},
                  #container{id=28,weight=283},
                  #container{id=29,weight=331},
                  #container{id=30,weight=136}
                 ],
    Ports = [
             #port{
                id=1,
                name="New York",
                docks=['A','B','C','D'],
                container_cap=200
               },
             #port{
                id=2,
                name="San Francisco",
                docks=['A','B','C','D'],
                container_cap=200
               },
             #port{
                id=3,
                name="Miami",
                docks=['A','B','C','D'],
                container_cap=200
               }
            ],
    %% {port, dock, ship}
    Locations = [
                 {1,'B',1},
                 {1, 'A', 3},
                 {3, 'C', 2},
                 {2, 'D', 4},
                 {2, 'B', 5}
                ],
    Ship_Inventory = #{
      1=>[14,15,9,2,6],
      2=>[1,3,4,13],
      3=>[],
      4=>[2,8,11,7],
      5=>[5,10,12]},
    Port_Inventory = #{
      1=>[16,17,18,19,20],
      2=>[21,22,23,24,25],
      3=>[26,27,28,29,30]
     },
    #shipping_state{ships = Ships, containers = Containers, ports = Ports, ship_locations = Locations, ship_inventory = Ship_Inventory, port_inventory = Port_Inventory}.
