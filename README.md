# BaseTouchPortalInterface
Copyright &copy; 2022 AthenaOfDelphi

This repository contains the files required to create custom Touch Portal plug-in interfaces for Delphi.  Custom interfaces can be minimally crafted using the code annotation attributes provided.

It is offered under the MPL (Version 2.0), details of which can be found in LICENSE.

# Introduction
The class **TBaseTouchPortalInterface** provides all functionality required to connect to Touch Portal.  To create your own interface follow these simple steps...

  * Create a new unit
  * Add **BaseTouchPortalInterface** and **TouchPortalInterfaceAttributes** to the uses clause
  * Define a new class that inherits from **TBaseTouchPortalInterface**
  * Define handlers for the various messages
  * Annotate the handlers using the attributes from **TouchPortalInterfaceAttributes**

To use the interface...

  * Create an instance of your interface class
  * Hook up the logging events you require
  * Call **initialise** - This method uses RTTI to create the message/method links (returns true/false to indicate success or failure)
  * Provide any further configuration information your interface needs
  * Call the **start** method of your interface class
  * Hopefully... sit back, relax and enjoy your new Touch Portal Interface

# Usage
The following sections provide some basic usage examples for this interface implementation.

## Action Data (the 'data' portion of messages)
Various messages sent from Touch Portal include a 'data' portion within the message.  This applies to actions and connectors which can define data they require from the user.  When an **action**, **up**, **down** or **connectorChange** change message is sent, this data will be included in the message.

As I discussed in a little [retrospective](https://athena.outer-reaches.com/blog/2022/07/03/touch-portal-plugin-development-a-review/) I wrote about implementing my first interface, this data isn't presented in a particularly friendly way in the messages.  You have to iterate the items of an array pulling out the IDs and values of the various items.  To make life easier within the interface, this is done automatically within the base interface and is presented to you as a TStringList (**actionData**) containing the key/value pairs extracted from the message.  If no 'data' portion is present, **actionData** will be nil.

For example:-

```
{
  "type":"connectorChange",
  "pluginId":"myplugin01",
  "connectorId":"myconnector01",
  "value":25,
  "data": [
    {
      "id":"field",
      "value":"xpos"
    },
    {
      "id":"object",
      "value":"camera"
    }
  ]
}
```

**actionData** will contain the following:-

```
Item[0] => field=xpos
Item[1] => object=camera
```

You can then access the values using **actionData.values['field']** for example.

## Defining the interface using the provided attributes
### Defining the plug-in ID
The plug-in ID is defined by the plug-in definition and for the most part it serves as little more than a means of ensuring we are only processing messages for our plug-in (it is included in most of the messages we receive and is checked so we only process our messages).  It is also used for identifying connectors.

To provide the plug-in ID for your interface, simply annotate the class descended from **TBaseTouchPortalInterface** using the **TPIPluginId** attribute.

```
type
  [TPIPluginId('myplugin01')]
  TMyPluginInterface = class(TBaseTouchPortalInterface)
  ...
```

This will set the internal plug-in ID to **myplugin01**.  This should reflect the ID specified in the plug-ins [**entry.tp**](https://www.touch-portal.com/api/index.php?section=structure).  Beyond specifying it, you shouldn't need to worry about this as wherever it is required, the interface will add/remove it as needed.

### Defining handlers for 'action', 'up' and 'down' messages
The prototype for action handlers is:-

`procedure(sender: TObject; actionId: string; actionData: TStringList) of object`

To link a handler to the various action messages the **TPIAction**, **TPIActionDown** and **TPIActionUp** attributes are used.

```
  [TPIAction('myaction001')]
  procedure myAction001Handler(sender: TObject; actionId: string; actionData: TStringList);
```

This annotation will link the **myAction001Handler** method to the Touch Portal **action** message type for action ID **myaction001**.  The **TPIActionDown** and **TPIActionUp** attributes should only be used for action that implement hold functionality.

### Defining handlers for 'connectorChange' messages
The prototype for connector change handlers is:-

`procedure(sender: TObject; connectorId: string; shortId: string; value: integer; actionData: TStringList) of object`

To link a handler to a connector change message the **TPIConnectorChange** attribute is used.

```
  [TPIConnectorChange('myconnector001')]
  procedure myconnector001Change(sender: TObject; connectorId: string; shortId: string; value: integer; actionData: TStringList);
```

This annotation will link the **myconnector001Change** method to the Touch Portal **connectorChange** message type for connector ID **myconnector001**.  Whilst **shortId** is provided, it is not required for updating the connector.  If multiple instances of a connector exist, the **actionData** is used to identify a specific instance of it.

### Defining handlers for 'listChange' messages
The prototype for list change handlers is:-

`procedure(sender: TObject; listId: string; actionId: string; instanceId: string; value: string) of object`

To link a handler to a list change message the **TPIListChange** attribute is used.

```
  [TPIListChange('mylist001')]
  procedure mylist001Change(sender: TObject; listId: string; actionId: string; instanceId: string; value: string);
```

This annotation will link the **mylist001Change** method to the Touch Portal **listChange** message type for list ID **mylist001**.

### Defining a handler for the 'closePlugin' message
The prototype for the close plug-in handler is:-

`procedure(sender: TObject) of object`

To link a handler to the close plug-in message the **TPIClosePlugin** attribute is used.

```
  [TPIClosePlugin()]
  procedure closePlugin(sender: TObject);
```

This annotation will link the **closePlugin** method to the Touch Portal **closePlugin** message.  **NOTE:-** It is not necessary for you to handle this message if all you want to do is attempt to reconnect.  By default the interface will set the reconnect timer to 20 seconds and trigger a reconnection attempt by disconnecting the socket from Touch Portal.  This message appears to be sent only when Touch Portal is closing (during a restart for example) or when the plug-in is disabled/removed from Touch Portal.  If you wish to prevent this automatic reconnection, set the property **reconnectOnClose** to false.

### Defining handlers for 'broadcast' messages
**NOTE:-** At this time the only broadcast message provided is 'pageChange' which is sent whenever the active page is changed.

The prototype for broadcast handlers is:-

`procedure(sender: TObject; eventName: string; broadcastMsg: TJSONValue) of object`

To link a handler to a broadcast message the **TPIBroadcast** attribute is used.

```
  [TPIBroacast('pageChange')]
  procedure handlePageChange(sender: TObject; eventName: string; broadcastMsg: TJSONValue);
```

Unlike the other handlers, the format of this message is not particularly well defined.  For that reason, the entire message received from Touch Portal is presented to the handler as a JSON value allowing the user to extract the required information.

## Connector Update Methods
### connectorUpdate(connectorId: string; value: integer; actionData: string = '')
Update the specified connector to the specified value (0-100).  **actionData** is a string that is appended to the connector ID and is used to update additional data values on the connector.  If Touch Portal issues a short ID for the connector, this will be stored within the interface and will be automatically used instead of the standard ID provided in the plug-in definition.


## List Choice Update Methods
### choiceUpdate(listId: string; choices: TStringList)
Update the choices for the list specified by **listId**.  Internally, this calls **choiceUpdate(listId, '', choices)**.

### choiceUpdate(listId: string; instanceId: string; choices: TStringList)
Update the specified instance (**instanceId**) of the specified list (**listId**).


## State Management Methods
### createState(stateId: string; desc: string; default: string; parentGroup: string = '')
Create a soft state providing the ID (used internally), the description (what the Touch Portal user sees), the default value and if required, the group for the state.

### removeState(stateId: string)
Remove an existing soft state.

### updateState(stateId: string; newValue: string; allowEmpty: boolean; force: boolean)
Update state values within Touch Portal.  The same method is used to update both fixed and soft states.  To reduce unnecessary traffic, the interface will only send an update if the new value is different from the value it has cached.  You can override this by setting **force** to true.  It will also not send updates for empty values, so if you would like to send an empty value, you should set **allowEmpty** to true.

## Status Events
The base class provides the following status events.

  * **onConnected(sender: TObject)** - Fired when the TCP socket connects to Touch Portal
  * **onDisconnected(sender: TObject)** - Fired when the TCP socket disconnects from Touch Portal
  * **onPaired(sender: TObject)** - Fired when the interface is paired with Touch Portal

The **onPaired** event is useful for triggering the creation of soft states (those defined at run time rather than being defined in the plug-in defintion).

If you would prefer not to use eventing you can override **doHandleConnected**, **doHandleDisconnected** and **doHandlePaired**.  As defined in the base class, these methods call the event handlers so if you wish to do both, you must call inherited.

## Logging
The base class provides numerous logging events.

  * **onLog(sender: TObject; msg: string)** - Used for general logging
  * **onLogDbg(sender: TObject; msg: string)** - Used for debug messages (actual code is only compiled in when **DEBUG** is defined)
  * **onLogComs(sender: TObject; msg: string)** - Communications logging (>> TP = Messages sent to Touch Portal, TP >> = messages sent by Touch Portal)
  * **onLogError(sender: TObject; msg: string)** - Used for logging errors
  * **onLogException(sender: TObject; msg: string; e: exception)** - Used for logging exceptions

None of these events are used too heavily, that is to say the logging could possibly be improved :)

If you would rather not use events, you can override the methods **log**, **logDbg**, **logComs**, **logError** and **logException**.  **NOTE:-** The **TBaseTouchPortalInterface** implementation of **logDbg** includes conditional defines to only include the code for debug builds.


# Real World Example
Within the 'example' directory you will find three files.  **entry.tp** is the actual definition file for the Touch Portal plug-in used by StreamHelper (my own software that provides features similar to Aitum and StreamerBot).  **StreamHelperTouchPortalInterface.pas** is the partial source for the interface within Delphi (it is by no means the complete implementation, but includes various examples that illustrate the key points of using this interface).  For context, **MainApplicationUsage.pas** provides an example of the creation/initialisation of the interface and the event handlers it uses (this file is just snippets from the main codebase of StreamHelper - if you have questions, get in touch).


# History
The original version of this was a one file fits all completely custom implementation of the interface as defined by my Stream Helper plug-in.  As such it had grown somewhat organically as I'd added features and despite being relatively small it was already a maintenance nightmare when adding implementations for new actions, lists etc.

This version is essentially that codebase but without the hard coded elements that bound it to my plug-in.  Overall it has been quite heavily tested but since this version fundamentally changes the message handling it should be noted there could be bugs.  Since completing this, I've reimplemented my plug-in interface using it and it appears to work just fine.

There were a few issues with disconnects and handling the situation where Touch Portal restarts, but I believe these have been fixed as the interface shuts down just fine when my application is closing and correctly handles a Touch Portal restart (this is something you are likely to do a lot of if you are developing your own plug-ins as it is required to fully remove an old version of a plug-in before installing the new version)


# Touch Portal
[Touch Portal](https://www.touch-portal.com/) is a combination of a desktop app and a mobile/tablet app that allows you to build highly configurable control surfaces.  In the world of streaming, it is a direct competitor to hardware products such as the Elgato Stream Deck, but it's uses are not limited to streaming and through the use of [custom plug-ins and it's API](https://www.touch-portal.com/api/) it's feature set can be greatly enhanced.


# Some Technical Details
The interface has been developed using Delphi 10.1 (Berlin) and uses the standard Indy components (specifically TIdTCPClient) for communications with Touch Portal.  All updates through the update routines provided by the interface will be executed in the context of the calling thread, whilst all messages received will be executed in the context of the reader thread (See **fReader: TTouchPortalInterfaceReader** in the source).  This is an important thing to consider, especially if you want your handlers to interact with a user interface.  For the most part, the UI will not be thread safe meaning you should use some form of messaging to have changes processed by the main application thread.  In the case of my interface (some of which is provided in the example files), I use Windows **postMessage** to push action messages into the main messaging loop of the application which guarantees they will be executed in the context of the main VCL thread.

If you are relatively new to Delphi and have never looked into using RTTI (run-time type information), take a look at the **initialise** method of **TBaseTouchPortalInterface** class.  I have tried to provide enough comments to make it clear what's going on, but essentially it uses RTTI to get a list of methods and then for each method, a list of the attributes attached to it.  The attributes are then decoded to establish which handler dictionary should contain the link to the method.  The dictionary entries are typed to the appropriate method prototype so we can simply call them from the message type handlers in the base class.  For example:-

```
  fActionHandlers.items[actionId](self, actionId, actionData);
```

# Contact and Issues
If you find issues with the interface or have feature requests, please raise an issue on the repository on Github.  This interface is used in my own projects, so as new features become available within the Touch Portal API it is highly likely they will be added regardless of whether they are requested or not.

If you would like an bespoke interface creating, please get in touch to discuss it.

The best place for getting in touch is my Discord server - [Athena's Pad](https://discord.gg/HnNpCxG).