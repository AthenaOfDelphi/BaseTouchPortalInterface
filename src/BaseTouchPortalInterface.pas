unit BaseTouchPortalInterface;

//------------------------------------------------------------------------------
//  BaseTouchPortalInterface.pas
//
//  Copyright (C) 2022 AthenaOfDelphi
//------------------------------------------------------------------------------

interface

uses
  // System Units
  System.Classes,
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  System.RTTI,
  // Additional Components
  VCL.ExtCtrls, // TTimer
  // Windows Specific Units
  WinAPI.Windows,
  WinAPI.Messages,
  // Indy Socket Components
  IdComponent,
  IdGlobal,
  IdThreadComponent,
  IdTCPClient,
  IdTCPConnection,
  // Custom Attributes
  TouchPortalInterfaceAttributes;

type
  //------------------------------------------------------------------------------
  // Method prototype definitions for the various handlers message handlers

  TTouchPortalActionHandler = procedure(sender: TObject; actionId: string; actionData: TStringList) of object;
  TTouchPortalConnectorChangeHandler = procedure(sender: TObject; connectorId: string; shortId: string; value: integer; actionData: TStringList) of object;
  TTouchPortalListChangeHandler = procedure(sender: TObject; listId: string; actionId: string; instanceId: string; value: string) of object;
  TTouchPortalClosePluginHandler = procedure(sender: TObject) of object;
  TTouchPortalBroadcastHandler = procedure(sender: TObject; eventName: string; broadcastMsg: TJSONValue) of object;

  //------------------------------------------------------------------------------
  // Interface exception class

  ETouchPortalInterfaceException = class(exception);

  //------------------------------------------------------------------------------
  // Current state of the Touch Portal Interface connection

  TBaseTouchPortalInterfaceState = (tpNotConnected, tpConnected, tpPaired);

  //------------------------------------------------------------------------------
  // Forward declaration of the base interface (to allow use in the socket reader thread class)

  TBaseTouchPortalInterface = class;

  //------------------------------------------------------------------------------
  // Thread to read data from the Touch Portal socket connection

  TTouchPortalInterfaceReader = class(TThread)
  protected
    fCon: TIdTCPConnection;
    fTPI: TBaseTouchPortalInterface;

    procedure Execute; override;
  public
    constructor create(tpi: TBaseTouchPortalInterface; acon: TIdTCPConnection);
  end;

  //------------------------------------------------------------------------------
  // Method prototypes for the logging events (all events use TTouchPortalInterfaceLogEvent
  // except OnLogException which uses TTouchPortalInterfaceLogExceptionEvent)

  TTouchPortalInterfaceLogEvent = procedure(sender: TObject; msg: string) of object;
  TTouchPortalInterfaceLogExceptionEvent = procedure(sender: TObject; msg: string; e: exception) of object;

  //------------------------------------------------------------------------------
  // Dictionary definitions for handler lists

  TTouchPortalActionHandlers = TDictionary<string, TTouchPortalActionHandler>;
  TTouchPortalConnectorChangeHandlers = TDictionary<string, TTouchPortalConnectorChangeHandler>;
  TTouchPortalListChangeHandlers = TDictionary<string, TTouchPortalListChangeHandler>;
  TTouchPortalBroadcastHandlers = TDictionary<string, TTouchPortalBroadcastHandler>;

  //------------------------------------------------------------------------------
  // Base interface class - Descend your interface from this class and link up handlers
  // for the various messages from Touch Portal using the attributes defined in
  // TouchPortalInterfaceAttributes

  TBaseTouchPortalInterface = class(TObject)
  protected
    // Internal state/variables
    fTP: TIdTCPClient;
    fTPState: TBaseTouchPortalInterfaceState;
    fCurrentStates: TStringList;
    fReader: TTouchPortalInterfaceReader;
    fActive: boolean;
    fReconnectOnClose: boolean;
    fHWND: HWND;
    fPluginId: string;
    fReconnectTimer: TTimer;

    // Socket events (for external handling of socket/connection related events
    fOnConnected: TNotifyEvent;
    fOnDisconnected: TNotifyEvent;
    fOnPaired: TNotifyEvent;

    // Connector Identity Lookups
    fShortConnectorIdentitiesById: TDictionary<string, string>;

    // Logging events
    fOnLog: TTouchPortalInterfaceLogEvent;
    fOnLogDbg: TTouchPortalInterfaceLogEvent;
    fOnLogComs: TTouchPortalInterfaceLogEvent;
    fOnLogError: TTouchPortalInterfaceLogEvent;
    fOnLogException: TTouchPortalInterfaceLogExceptionEvent;

    // Handler lists
    fActionHandlers: TTouchPortalActionHandlers;
    fActionUpHandlers: TTouchPortalActionHandlers;
    fActionDownHandlers: TTouchPortalActionHandlers;
    fConnectorChangeHandlers: TTouchPortalConnectorChangeHandlers;
    fClosePluginHandler: TTouchPortalClosePluginHandler;
    fBroadcastHandlers: TTouchPortalBroadcastHandlers;
    fListChangeHandlers: TTouchPortalListChangeHandlers;

    // Windows message handler (serves only to allow the use of TTimer)
    procedure wndProc(var msg: TMessage);

    // Getter for the 'connected' property.  Will only be true when socket is connected
    // and pairing has been completed
    function getConnected: boolean;

    // Extract the 'data' portion of messages (data) and create key/value list
    // in actionData (if no 'data' portion exists, actionData will be nil)
    procedure extractMessageData(data: TJSONValue; var actionData: TStringList);

    // Generic handler for 'action', 'up' and 'down' messages
    procedure doHandleAction(desc: string; handlers: TTouchPortalActionHandlers; data: TJSONValue);

    // Handlers for messages from Touch Portal
    procedure handleAction(data: TJSONValue);
    procedure handleUp(data: TJSONValue);
    procedure handleDown(data: TJSONValue);
    procedure handleConnectorChange(data: TJSONValue);
    procedure handleListChange(data: TJSONValue);
    procedure handleClosePlugin;
    procedure handleBroadCast(data: TJSONValue);

    // Socket/socket reader event handlers
    procedure handleSocketConnect(sender: TObject);
    procedure handleSocketDisconnect(sender: TObject);
    procedure handleData(sender: TObject; data: string);
    procedure handleReaderTerminate(sender: TObject);

    // Stop the reader thread and clean it up
    procedure stopReader;

    // Send a message to Touch Portal
    procedure send(msg: string);

    // Reconnection method
    procedure attemptReconnect(sender: TObject);

    // Setter for interface 'active' status
    procedure setActive(value: boolean);

    // Internal 'state' updater (used to update hard statuses defined in the plug-in definition and
    // soft statuses defined at runtime by the interface)
    procedure stateUpdate(id: string; value: string; allowEmpty: boolean = false; force: boolean = false);

    //------------------------------------------------------------------------------
    // Descendant classes can override these methods to handle the socket state changes
    // or they can rely on the events (the events are raised by these methods, so if
    // you would like to do both, be sure to call inherited)

    procedure doHandleConnected; virtual;
    procedure doHandleDisconnected; virtual;
    procedure doHandlePaired; virtual;

    //------------------------------------------------------------------------------
    // These methods are used for logging throughout the interface.  If you wish
    // to handle the logging directly, override these methods.  As defined in this
    // class they raise various events which correspond to the logging type

    procedure log(sender: TObject; msg: string); virtual;
    procedure logDbg(sender: TObject; msg: string); virtual;
    procedure logComs(sender: TObject; msg: string); virtual;
    procedure logError(sender: TObject; msg: string); virtual;
    procedure logException(sender: TObject; msg: string; e: exception); virtual;

    //------------------------------------------------------------------------------
  public
    constructor create(tpPort: word = 12136; tpHost: string = '127.0.0.1');
    destructor Destroy; override;

    //------------------------------------------------------------------------------
    // Initialisation - Call this after you have linked up any logging events you require

    function initialise: boolean;

    //------------------------------------------------------------------------------
    // Interface control routines

    procedure start;
    procedure stop;

    //------------------------------------------------------------------------------
    // State management routines

    procedure createState(stateId: string; desc: string; default: string; parentGroup: string = '');
    procedure removeState(stateId: string);
    procedure updateState(stateId: string; newValue: string; allowEmpty: boolean; force: boolean);

    //------------------------------------------------------------------------------
    // List choice update routines

    procedure choiceUpdate(listId: string; choices: TStringList); overload;
    procedure choiceUpdate(listId: string; instanceId: string; choices: TStringList); overload;

    //------------------------------------------------------------------------------
    // Connector update routines

    procedure connectorUpdate(connectorId: string; value: integer; actionData: string = '');

    //------------------------------------------------------------------------------
    // Status properties

    property active: boolean read fActive write setActive;
    property reconnectOnClose: boolean read fReconnectOnClose write fReconnectOnClose;
    property connected: boolean read getConnected;

    //------------------------------------------------------------------------------
    // Connection status events

    property onConnected: TNotifyEvent read fOnConnected write fOnConnected;
    property onDisconnected: TNotifyEvent read fOnDisconnected write fOnDisconnected;
    property onPaired: TNotifyEvent read fOnPaired write fOnPaired;

    //------------------------------------------------------------------------------
    // Logging events

    property onLog: TTouchPortalInterfaceLogEvent read fOnLog write fOnLog;
    property onLogDbg: TTouchPortalInterfaceLogEvent read fOnLogDbg write fOnLogDbg;
    property onLogComs: TTouchPortalInterfaceLogEvent read fOnLogComs write fOnLogComs;
    property onLogError: TTouchPortalInterfaceLogEvent read fOnLogError write fOnLogError;
    property onLogException: TTouchPortalInterfaceLogExceptionEvent read fOnLogException write fOnLogException;
  end;

implementation

uses
  IdException,
  IdExceptionCore,
  IdURI;

//------------------------------------------------------------------------------
// Local utility routines

function removeCRLF(src: string): string;
begin
  result := stringReplace(stringReplace(src, #13, '', [rfReplaceAll]), #10, '', [rfReplaceAll]);
end;

//------------------------------------------------------------------------------
// Socket Reader

constructor TTouchPortalInterfaceReader.create(tpi: TBaseTouchPortalInterface; aCon: TIdTCPConnection);
begin
  fCon := aCon;
  fTPI := tpi;

  inherited create(false);
end;

procedure TTouchPortalInterfaceReader.execute;
var
  data: string;
begin
  fTPI.logDbg(self, 'TTouchPortalInterfaceReader.execute - Started');

  while (not terminated) and (fCon.Connected) do
  begin
    try
      data := fCon.ioHandler.readLn(#13#10, 1000);
      if (data <> '') then
      begin
        fTPI.logComs(self, format('TP >> %s', [data]));

        fTPI.handleData(self, data);
      end;
    except
      on e:EIdSilentException do
      begin
        // Silent indy exception just ignore it
      end;
      on e:EIdNotConnected do
      begin
        // This may be expected... do nothing
      end;
      on e:exception do
      begin
        fTPI.logException(self, 'Exception in TTouchPortalInterfaceReader.execute', e); // format('Exception in reader execute - (%s) %s', [e.className, e.message]));
      end;
    end;
  end;

  fTPI.logDbg(self, 'TTouchPortalInterfaceReader.execute - Ended');
end;

//------------------------------------------------------------------------------
// Base Touch Portal Interface

procedure TBaseTouchPortalInterface.log(sender: TObject; msg: string);
begin
  if (assigned(fOnLog)) then
  begin
    fOnLog(sender, msg);
  end;
end;

procedure TBaseTouchPortalInterface.logDbg(sender: TObject; msg: string);
begin
  {$IFDEF DEBUG}
  if (assigned(fOnLogDbg)) then
  begin
    fOnLogDbg(sender, msg);
  end;
  {$ENDIF}
end;

procedure TBaseTouchPortalInterface.logComs(sender: TObject; msg: string);
begin
  if (assigned(fOnLogComs)) then
  begin
    fOnLogComs(sender, removeCRLF(msg));
  end;
end;

procedure TBaseTouchPortalInterface.logError(sender: TObject; msg: string);
begin
  if (assigned(fOnLogError)) then
  begin
    fOnLogError(sender, msg);
  end;
end;

procedure TBaseTouchPortalInterface.logException(sender: TObject; msg: string; e: exception);
begin
  if (assigned(fOnLogException)) then
  begin
    fOnLogException(sender, msg, e);
  end;
end;

procedure TBaseTouchPortalInterface.stateUpdate(id: string; value: string; allowEmpty: boolean = false; force: boolean = false);
begin
  if ((fCurrentStates.values[id] <> value) or force) and ((value <> '') or allowEmpty) then
  begin
    fCurrentStates.values[id] := value;
    send(format('{"type":"stateUpdate","id":"%s","value":"%s"}', [id, value]));
  end;
end;

constructor TBaseTouchPortalInterface.create(tpPort: word = 12136; tpHost: string = '127.0.0.1');
begin
  inherited create;

  // Allocate a window handler (required for using TTimer)
  fHWND := AllocateHWnd(self.wndProc);

  fActive := false;
  fReconnectOnClose := true;
  fPluginId := '';

  fReconnectTimer := TTimer.create(nil);
  fReconnectTimer.OnTimer := attemptReconnect;
  fReconnectTimer.enabled := false;
  fReconnectTimer.interval := 1000;

  fTP := TIdTCPClient.create(nil);
  fTP.Port := tpPort;
  fTP.Host := tpHost;
  fTPState := tpNotConnected;

  fTP.OnConnected := handleSocketConnect;
  fTP.OnDisconnected := handleSocketDisconnect;

  fCurrentStates := TStringList.create;
  fReader := nil;

  fShortConnectorIdentitiesById := TDictionary<string, string>.create;

  // Process the attributes etc. here
  fActionHandlers := TTouchPortalActionHandlers.create;
  fActionUpHandlers := TTouchPortalActionHandlers.create;
  fActionDownHandlers := TTouchPortalActionHandlers.create;
  fConnectorChangeHandlers := TTouchPortalConnectorChangeHandlers.create;
  fListChangeHandlers := TTouchPortalListChangeHandlers.create;
  fClosePluginHandler := nil;
  fBroadcastHandlers := TTouchPortalBroadcastHandlers.create;
end;

function TBaseTouchPortalInterface.initialise: boolean;
var
  aCtx: TRttiContext;
  aType: TRttiType;
  aMethod: TRttiMethod;
  anAttr: TCustomAttribute;
  theMethod: TMethod;
  anAction: TPIAction;
  anActionUp: TPIActionUp;
  anActionDown: TPIActionDown;
  aConnectorChange: TPIConnectorChange;
  aBroadcast: TPIBroadcast;
  aListChange: TPIListChange;
  connectorId: string;
begin
  result := true;

  // Create an RTTI context
  aCtx := TRttiContext.create;

  // Get the type information for 'self'.  This will be your interface class
  aType := aCtx.getType(self.classInfo);

  try
    // Iterate through the attributes attached to the class definition looking for
    // our plug-in ID attribute
    for anAttr in aType.GetAttributes do
    begin
      if (anAttr is TPIPluginId) then
      begin
        fPluginId := TPIPluginId(anAttr).pluginId;
        log(self, format('Touch Portal plug-in ID - %s', [fPluginId]));
      end
      else
      begin
        raise ETouchPortalInterfaceException.createFmt('Unhandled custom attribute (%s) for class (%s)',
          [anAttr.ClassName, self.className]);
      end;
    end;

    // If we don't have a plug-in ID, raise an exception to abort... we need a plugin ID
    if (fPluginId = '') then
    begin
      raise ETouchPortalInterfaceException.createFmt('Cannot proceed - No plug-in ID provided for interface class (%s)',
        [self.className]);
    end;

    // Now get the methods belonging to the interface class
    for aMethod in aType.GetMethods do
    begin
      // Setup a TMethod instance that could be used to call the method we are looking at
      theMethod.Code := aMethod.CodeAddress;
      theMethod.Data := self;

      // Loop through the attributes attached to the method
      for anAttr in aMethod.getAttributes do
      begin
        if (anAttr is TPIAction) then
        begin
          // Link an 'action' message handler
          anAction := TPIAction(anAttr);

          if (fActionHandlers.ContainsKey(anAction.actionId)) then
          begin
            raise ETouchPortalInterfaceException.createFmt('Action %s - Multiple handlers detected (Method %s)',
              [anAction.actionId, aMethod.Name]);
          end
          else
          begin
            // Add the handler to our list, typecasting the TMethod to the correct prototype for the dictionary
            fActionHandlers.add(anAction.actionId, TTouchPortalActionHandler(theMethod));
            log(self, format('Action handler - %s => %s', [anAction.actionid, aMethod.name]));
          end;
        end else if (anAttr is TPIActionUp) then
        begin
          // Link an 'up' message handler
          anActionUp := TPIActionUp(anAttr);

          if (fActionHandlers.ContainsKey(anActionUp.actionId)) then
          begin
            raise ETouchPortalInterfaceException.createFmt('Action up %s - Multiple handlers detected (Method %s)',
              [anActionUp.actionId, aMethod.Name]);
          end
          else
          begin
            fActionUpHandlers.add(anActionUp.actionId, TTouchPortalActionHandler(theMethod));
            log(self, format('Up handler - %s => %s', [anActionUp.actionid, aMethod.name]));
          end;
        end else if (anAttr is TPIActionDown) then
        begin
          // Link a 'down' message handler
          anActionDown := TPIActionDown(anAttr);

          if (fActionHandlers.ContainsKey(anActionDown.actionId)) then
          begin
            raise ETouchPortalInterfaceException.createFmt('Action down %s - Multiple handlers detected (Method %s)',
              [anActionDown.actionId, aMethod.Name]);
          end
          else
          begin
            fActionDownHandlers.add(anActionDown.actionId, TTouchPortalActionHandler(theMethod));
            log(self, format('Down handler - %s => %s', [anActionDown.actionid, aMethod.name]));
          end;
        end else if (anAttr is TPIListChange) then
        begin
          // Link a 'listChange' message handler
          aListChange := TPIListChange(anAttr);

          if (fListChangeHandlers.containsKey(aListChange.listId)) then
          begin
            raise ETouchPortalInterfaceException.createFmt('List change %s - Multiple handlers detected (Method %s)',
              [aListChange.listId, aMethod.name]);
          end
          else
          begin
            fListChangeHandlers.add(aListChange.listId, TTouchPortalListChangeHandler(theMethod));
            log(self, format('List change handler - %s => %s', [aListChange.listId, aMethod.name]));
          end;
        end else if (anAttr is TPIConnectorChange) then
        begin
          // Link a 'connectorChange' message handler
          aConnectorChange := TPIConnectorChange(anAttr);

          if (fConnectorChangeHandlers.containsKey(connectorId)) then
          begin
            raise ETouchPortalInterfaceException.createFmt('Connector change %s - Multiple handlers detected (Method %s)',
              [aConnectorChange.connectorId, aMethod.name]);
          end
          else
          begin
            fConnectorChangeHandlers.add(aConnectorChange.connectorId, TTouchPortalConnectorChangeHandler(theMethod));
            log(self, format('Connector change handler - %s => %s', [aConnectorChange.connectorId, aMethod.name]));
          end;
        end else if (anAttr is TPIBroadcast) then
        begin
          // Link a 'broadcast' message handler
          aBroadcast := TPIBroadcast(anAttr);

          if (fBroadcastHandlers.containsKey(aBroadcast.eventName)) then
          begin
            raise ETouchPortalInterfaceException.createFmt('Broadcast %s - Multiple handlers detected (Method %s)',
              [aBroadcast.eventName, aMethod.name]);
          end
          else
          begin
            fBroadcastHandlers.add(aBroadcast.eventName, TTouchPortalBroadcastHandler(theMethod));
            log(self, format('Broadcast handler - %s => %s', [aBroadcast.eventName, aMethod.name]));
          end;
        end else if (anAttr is TPIClosePlugin) then
        begin
          // Link the 'closePlugin' message handler
          if (assigned(fClosePluginHandler)) then
          begin
            raise ETouchPortalInterfaceException.createFmt('Close Plugin - Multiple handlers detected (Method %s)',
              [aMethod.name]);
          end
          else
          begin
            fClosePluginHandler := TTouchPortalClosePluginHandler(theMethod);
            log(self, format('Close plug-in handler - %s', [aMethod.name]));
          end;
        end
        else
        begin
          raise ETouchPortalInterfaceException.createFmt('Unhandled custom attribute (%s) for method (%s)',
            [anAttr.ClassName, aMethod.Name]);
        end;
      end;
    end;
  except
    on e: exception do
    begin
      logException(self, 'Exception during initialisation', e);
      result := false;
    end;
  end;

  aCtx.free;
end;

destructor TBaseTouchPortalInterface.Destroy;
begin
  stop;

  fShortConnectorIdentitiesById.free;
  fCurrentStates.free;
  fTP.free;
  fReconnectTimer.free;

  fActionHandlers.free;
  fActionUpHandlers.free;
  fActionDownHandlers.free;
  fConnectorChangeHandlers.free;
  fBroadcastHandlers.free;
  fListChangeHandlers.free;

  DeallocateHWnd(fHWND);

  inherited;
end;

procedure TBaseTouchPortalInterface.send(msg: string);
begin
  if (fTPState <> tpNotConnected) then
  begin
    logComs(self, format('>> TP - %s', [msg]));
    try
      fTP.Socket.Write(msg + #10, IndyTextEncoding_UTF8);
    except
      on e:exception do
      begin
        logException(self, 'Exception sending data to Touch Portal', e);
        handleSocketDisconnect(nil);
      end;
    end;
  end;
end;

procedure TBaseTouchPortalInterface.handleReaderTerminate(sender: TObject);
begin
  logDbg(self, 'Unexpected reader termination');
  handleSocketDisconnect(nil);
end;

procedure TBaseTouchPortalInterface.stopReader;
begin
  if (assigned(fReader)) then
  begin
    logDbg(self, 'StopReader - Shutting down reader');

    try
      fReader.onTerminate := nil;

      fReader.FreeOnTerminate := true;
      fReader.terminate;

      logDbg(self, 'StopReader - Done');
    except
      on e:Exception do
      begin
        logException(self, 'Exception shutting down reader', e);
      end;
    end;

    fReader := nil;
  end
  else
  begin
    logDbg(self, 'StopReader - Reader not initialised');
  end;
end;

procedure TBaseTouchPortalInterface.handleSocketConnect(sender: TObject); //  socket: TCustomWinSocket);
begin
  log(self, 'Connected to Touch Portal');

  if (assigned(fReader)) then
  begin
    stopReader;
  end;

  fReader := TTouchPortalInterfaceReader.create(self, fTP);
  fReader.onTerminate := handleReaderTerminate;
  fTPState := tpConnected;

  doHandleConnected;

  send(format('{"type":"pair","id":"%s"}', [fPluginId]));
end;

procedure TBaseTouchPortalInterface.handleSocketDisconnect(sender: TObject); // ; socket: TCustomWinSocket);
begin
  log(self, 'Disconnected from Touch Portal');

  fTPState := tpNotConnected;

  if (assigned(fReader)) then
  begin
    stopReader;
  end;

  try
    if (fTP.connected) then
    begin
      fTP.disconnect;
    end;
  except
    on e:exception do
    begin
      logException(self, 'Exception in handleDisconnect', e);
    end;
  end;

  doHandleDisconnected;

  if (fActive) then
  begin
    log(self, 'Starting reconnect timer');
    fReconnectTimer.enabled := true;
  end;
end;

procedure TBaseTouchPortalInterface.doHandleConnected;
begin
  if (assigned(fOnConnected)) then
  begin
    fOnConnected(self);
  end;
end;

procedure TBaseTouchPortalInterface.doHandleDisconnected;
begin
  if (assigned(fOnDisconnected)) then
  begin
    fOnDisconnected(self);
  end;
end;

procedure TBaseTouchPortalInterface.doHandlePaired;
begin
  if (assigned(fOnPaired)) then
  begin
    fOnPaired(self);
  end;
end;

function TBaseTouchPortalInterface.getConnected: boolean;
begin
  result := (fTPState = tpPaired);
end;

procedure TBaseTouchPortalInterface.attemptReconnect(sender: TObject);
begin
  fReconnectTimer.enabled := false;

  logDbg(self, 'Attempting to reconnect to Touch Portal');
  try
    fTP.Connect;
  except
    on e:exception do
    begin
      logException(self, 'Exception reconnecting', e);
    end;
  end;

  fReconnectTimer.interval := 1000;
  if (not fTP.connected) then
  begin
    fReconnectTimer.enabled := true;
  end;
end;

procedure TBaseTouchPortalInterface.start;
begin
  if (not fActive) then
  begin
    fActive := true;

    if (not fTP.connected) then
    begin
      fTP.connect;
    end;
  end;
end;

procedure TBaseTouchPortalInterface.stop;
begin
  fActive := false;

  if (fTP.connected) then
  begin
    try
      fTP.disconnect;
    except
    end;

    stopReader;
  end;

  if (fReconnectTimer.enabled) then
  begin
    fReconnectTimer.enabled := false;
  end;
end;

procedure TBaseTouchPortalInterface.setActive(value: boolean);
begin
  if (value <> fActive) then
  begin
    if (value) then
    begin
      start;
    end
    else
    begin
      stop;
    end;
  end;
end;

procedure TBaseTouchPortalInterface.wndProc(var msg: TMessage);
var
  handled: boolean;
begin
  handled := false;

  if (handled) then
  begin
    msg.result := 0;
  end
  else
  begin
    msg.result := defWindowProc(fHWnd, msg.msg, msg.wParam, msg.lParam);
  end;
end;

procedure TBaseTouchPortalInterface.extractMessageData(data: TJSONValue; var actionData: TStringList);
var
  items: TJSONArray;
  loop: integer;
  id: string;
  value: string;
begin
  actionData := nil;

  if (data.tryGetValue<TJSONArray>('data', items)) then
  begin
    if (items.Count > 0) then
    begin
      actionData := TStringList.create;
      for loop := 0 to items.count - 1 do
      begin
        if (items.Items[loop].TryGetValue<string>('id', id) and items.Items[loop].TryGetValue<string>('value', value)) then
        begin
          actionData.add(format('%s=%s', [id, value]));
        end
        else
        begin
          logError(self, format('Malformed data item - %s',
            [removeCRLF(items.Items[loop].ToJSON)]));
        end;
      end;
    end;
  end
end;

procedure TBaseTouchPortalInterface.doHandleAction(desc: string; handlers: TTouchPortalActionHandlers; data: TJSONValue);
var
  actionId: string;
  actionData: TStringList;
begin
  if (data.tryGetValue<string>('actionId', actionId)) then
  begin
    if (handlers.containsKey(actionid)) then
    begin
      extractMessageData(data, actionData);
      try
        handlers.items[actionId](self, actionId, actionData);
      except
        on e:exception do
        begin
          logException(self, format('Exception processing %s (%s)',
            [desc, actionId]), e);
        end;
      end;
    end
    else
    begin
      logError(self, format('No handler for %s (%s)',
        [desc, actionId]));
    end;
  end
  else
  begin
    logError(self, format('Invalid action message for %s (%s) - Missing action Id',
      [desc, removeCRLF(data.toJSON)]));
  end;
end;

procedure TBaseTouchPortalInterface.handleAction(data: TJSONValue);
begin
  doHandleAction('Action', fActionHandlers, data);
end;

procedure TBaseTouchPortalInterface.handleUp(data: TJSONValue);
begin
  doHandleAction('Up', fActionUpHandlers, data);
end;

procedure TBaseTouchPortalInterface.handleDown(data: TJSONValue);
begin
  doHandleAction('Down', fActionDownHandlers, data);
end;

procedure TBaseTouchPortalInterface.handleConnectorChange(data: TJSONValue);
var
  connectorId: string;
  value: integer;
  actionData: TStringList;
  shortId: string;
begin
  if (data.tryGetValue<string>('connectorId', connectorId) and data.tryGetValue<integer>('value', value)) then
  begin
    if (fShortConnectorIdentitiesById.containsKey(connectorId)) then
    begin
      shortId := fShortConnectorIdentitiesById.items[connectorId];
    end
    else
    begin
      shortId := '';
    end;

    if (fConnectorChangeHandlers.containsKey(connectorId)) then
    begin
      extractMessageData(data, actionData);
      try
        fConnectorChangeHandlers.items[connectorId](Self, connectorId, shortId, value, actionData);
      except
        on e:exception do
        begin
          logException(self, format('Exception processing connectorChange (%s)',
            [connectorId]), e);
        end;
      end;
    end
    else
    begin
      logError(self, format('No handler for connectorChange (%s)',
        [connectorId]));
    end;
  end
  else
  begin
    logError(self, format('Invalid connectorChange message (%s) - Missing connector Id or value',
      [removeCRLF(data.toJSON)]));
  end;
end;

procedure TBaseTouchPortalInterface.handleListChange(data: TJSONValue);
var
  actionId: string;
  listId: string;
  instanceId: string;
  value: string;
begin
  if (
    data.tryGetValue<string>('actionId', actionId) and
    data.tryGetValue<string>('listId', listId) and
    data.tryGetValue<string>('instanceId', instanceid)
    ) then
  begin
    if (not data.tryGetValue<string>('value', value)) then
    begin
      value := '';
    end;

    if (fListChangeHandlers.containsKey(listId)) then
    begin
      try
        fListChangeHandlers.items[listId](self, listId, actionId, instanceId, value);
      except
        on e:exception do
        begin
          logException(self, format('Exception processing listChange (%s)',
            [listId]), e);
        end;
      end;
    end;
  end
  else
  begin
    logError(self, format('Invalid listChange message (%s) - Missing action Id, list Id or instance Id',
      [removeCRLF(data.toJSON)]));
  end;
end;

procedure TBaseTouchPortalInterface.handleClosePlugin;
begin
  if (fReconnectOnClose) then
  begin
    fReconnectTimer.interval := 20000; // 20 Second delay (TP could be restarting)
    log(self, 'TP closed plug-in - Setting reconnect interval to 20 seconds');
  end;

  stopReader;

  try
    logDbg(self, 'Closing socket');
    fTP.Disconnect;
  except
    on e:exception do
    begin
      logException(self, 'Exception disconnecting from Touch Portal', e);
    end;
  end;

  fShortConnectorIdentitiesById.Clear;

  if (assigned(fClosePluginHandler)) then
  begin
    try
      fClosePluginHandler(self);
    except
      on e:exception do
      begin
        logException(self, 'Exception processing closePlugin', e);
      end;
    end;
  end;
end;

procedure TBaseTouchPortalInterface.handleBroadCast(data: TJSONValue);
var
  eventName: string;
begin
  if (data.tryGetValue<string>('event', eventName)) then
  begin
    if (fBroadcastHandlers.containsKey(eventName)) then
    begin
      try
        fBroadcastHandlers.items[eventName](self, eventName, data);
      except
        on e:exception do
        begin
          logException(self, format('Exception processing broadcast (%s)',
            [eventName]), e);
        end;
      end;
    end;
  end
  else
  begin
    logError(self, format('Invalid broadcast message (%s) - Missing event',
      [removeCRLF(data.toJSON)]));
  end;
end;

procedure TBaseTouchPortalInterface.handleData(sender: TObject; data: string);
var
  json: TJSONValue;
  msgtype: string;
  msgpluginid: string;
  connectorId: string;
  shortId: string;
  msg: string;
begin
  msg := data;

  try
    json := TJSONObject.ParseJSONValue(trim(msg));

    if (json.TryGetValue('type', msgtype)) then
    begin
      logDbg(self, format('MessageType - %s', [msgType]));

      if (fTPState = tpPaired) then
      begin
        logDbg(self, 'Processing data (paired)');

        if (msgType = 'broadcast') then
        begin
          handleBroadcast(json);
        end
        else
        begin
          if (json.tryGetValue<string>('pluginId', msgpluginid)) then
          begin
            if (msgpluginid = fPluginId) then
            begin
              if (msgType = 'action') then
              begin
                // Action press
                handleAction(json);
              end else if (msgType = 'down') then
              begin
                // Action Hold (Down)
                handleDown(json);
              end else if (msgType = 'up') then
              begin
                // Action Hold (Up)
                handleUp(json);
              end else if (msgType = 'shortConnectorIdNotification') then
              begin
                if (json.TryGetValue<string>('connectorId', connectorId) and json.TryGetValue<string>('shortId', shortId)) then
                begin
                  logDbg(self, format('Short connector ID for %s = %s', [connectorId, shortId]));

                  if (fShortConnectorIdentitiesById.containsKey(connectorId)) then
                  begin
                    fShortConnectorIdentitiesById.items[connectorId] := shortId;
                  end
                  else
                  begin
                    fShortConnectorIdentitiesById.add(connectorId, shortId);
                  end;
                end
                else
                begin
                  logError(self, format('Missing data from shortConnectorIdNotification (%s)', [removeCRLF(msg)]));
                end;
              end else if (msgType = 'connectorChange') then
              begin
                handleConnectorChange(json);
              end else if (msgType = 'listChange') then
              begin
                handleListChange(json);
              end else if (msgType = 'closePlugin') then
              begin
                handleClosePlugin;
              end else
              begin
                logError(self, format('Unknown message type - %s (%s)',
                  [msgType, removeCRLF(msg)]));
              end;
            end;
          end
          else
          begin
            logError(self, format('Message missing plug-in ID (%s)',
              [removeCRLF(msg)]));
          end;
        end;
      end
      else
      begin
        if (fTPState = tpConnected) then
        begin
          logDbg(self, 'Processing data (Unpaired)');

          if (msgtype = 'info') then
          begin
            log(self, 'Paired with TouchPortal');
            fTPState := tpPaired;

            doHandlePaired;
          end;
        end;
      end;
    end
    else
    begin
      logError(self, format('Touch Portal message missing type - %s', [removeCRLF(msg)]));
    end;
  except
    on E:Exception do
    begin
      logException(self, format('Exception processing Touch Portal message (%s)',
        [removeCRLF(msg)]), e);
    end;
  end;
end;

procedure TBaseTouchPortalInterface.createState(stateId: string; desc: string; default: string; parentGroup: string = '');
begin
  send(format('{"type":"createState","id":"%s","desc":"%s","defaultValue":"%s","parentGroup":"%s"}',
    [stateId, desc, default, parentGroup]));
end;

procedure TBaseTouchPortalInterface.removeState(stateId: string);
begin
  send(format('{"type":"removeState","id":"%s"}', [stateId]));
end;

procedure TBaseTouchPortalInterface.updateState(stateId: string; newValue: string; allowEmpty: boolean; force: boolean);
begin
  stateUpdate(stateId, newValue, allowEmpty, force);
end;

procedure TBaseTouchPortalInterface.choiceUpdate(listId: string; choices: TStringList);
begin
  choiceUpdate(listId, '', choices);
end;

procedure TBaseTouchPortalInterface.choiceUpdate(listId: string; instanceId: string; choices: TStringList);
var
  listValues: string;
  loop: integer;
begin
  listValues := '';
  if (assigned(choices)) then
  begin
    for loop := 0 to choices.count - 1 do
    begin
      if (listValues <> '') then
      begin
        listValues := listValues + ',';
      end;

      listValues := listValues + '"' + stringReplace(choices[loop], '"', '\"', [rfReplaceAll]) + '"';
    end;
  end;

  if (instanceId = '') then
  begin
    send(format('{"type":"choiceUpdate","id":"%s","value":[%s]}', [listId, listValues]));
  end
  else
  begin
    send(format('{"type":"choiceUpdate","id":"%s","instanceId":"%s","value":[%s]}', [listId, instanceId, listValues]));
  end;
end;

procedure TBaseTouchPortalInterface.connectorUpdate(connectorId: string; value: integer; actionData: string);
begin
  if (value < 0) or (value > 100) then
  begin
    logError(self, format('Connector update for %s - Value out of range (%d, should be 0 <= X <= 100)',
      [connectorId, value]));
  end;

  if (value < 0) then value := 0;
  if (value > 100) then value := 100;

  if (actionData <> '') then
  begin
    actionData := '|' + actionData;
  end;

  if (fShortConnectorIdentitiesById.containsKey(connectorId)) then
  begin
    send(format('{"type":"connectorUpdate","shortId":"%s%s","value":%d}', [fShortConnectorIdentitiesById.items[connectorId], actionData, value]));
  end
  else
  begin
    send(format('{"type":"connectorUpdate","connectorId":"pc_%s_%s%s","value":%d}', [fPluginId, connectorId, actionData, value]));
  end;
end;

end.
