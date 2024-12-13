The goal of this assignment is to create a simple chat application in Erlang which we dub TinyChat.

High-Level Overview
TinyChat is composed of the following core modules:

GUIs (gui.erl)

The graphical interface for the chat system.
Provided in its entirety; no implementation is required.
Clients (client.erl)

Represents individual chat users.
Partially implemented; requires completion of provided stubs.
Server (server.erl)

Manages connections between clients and chatrooms.
Partially implemented; requires completion of provided stubs.
Chatrooms (chatroom.erl)

Represents the individual chatrooms where users can interact.
Partially implemented; requires completion of provided stubs.
Additionally, there is a main module (main.erl) to initialize and run the system, along with auxiliary files provided to support the implementation.

User Interaction
The primary interface for interacting with TinyChat is the GUI, which enables users to:

View and manage system notifications via the System tab.
Access chatroom-specific tabs for ongoing conversations.
Enter commands using the command line entry pane at the bottom of the GUI window.
Example GUI
The GUI may include multiple tabs:

System Tab: General system notifications and commands.
Chatroom Tabs: Tabs for each chatroom a user has joined (e.g., #soccer).
Commands
Users interact with the TinyChat system by entering commands into the command line entry pane. Supported commands allow users to:

Join chatrooms.
Send and receive messages.
Manage chatroom participation.
