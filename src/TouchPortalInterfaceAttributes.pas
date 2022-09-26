unit TouchPortalInterfaceAttributes;

interface

type
  TPIPluginId = class(TCustomAttribute)
  protected
    fPluginId: string;
  public
    constructor create(const aPluginId: string);

    property pluginId: string read fPluginId;
  end;

  TPIAction = class(TCustomAttribute)
  protected
    fActionId: string;
  public
    constructor create(const anActionId: string);

    property actionId: string read fActionId;
  end;

  TPIActionDown = class(TCustomAttribute)
  protected
    fActionId: string;
  public
    constructor create(const anActionId: string);

    property actionId: string read fActionId;
  end;

  TPIActionUp = class(TCustomAttribute)
  protected
    fActionId: string;
  public
    constructor create(const anActionId: string);

    property actionId: string read fActionId;
  end;

  TPIListChange = class(TCustomAttribute)
  protected
    fListId: string;
  public
    constructor create(const aListId: string);

    property listId: string read fListId;
  end;

  TPIBroadcast = class(TCustomAttribute)
  protected
    fEventName: string;
  public
    constructor create(const anEventName: string);

    property eventName: string read fEventName;
  end;

  TPIConnectorChange = class(TCustomAttribute)
  protected
    fConnectorId: string;
  public
    constructor create(const aConnectorId: string);

    property connectorId: string read fConnectorId;
  end;

  TPIClosePlugin = class(TCustomAttribute);

implementation

uses
  System.SysUtils;

{ TPIPluginId }

constructor TPIPluginId.create(const aPluginId: string);
begin
  inherited create;

  if (aPluginId = '') then
  begin
    raise EArgumentException.createFmt('(%s) Expected a non-null string for the plug-in ID', [self.className]);
  end;

  fPluginId := aPluginId;
end;

{ TPIAction }

constructor TPIAction.create(const anActionId: string);
begin
  inherited create;

  if (anActionId = '') then
  begin
    raise EArgumentException.createFmt('(%s) Expected a non-null string for the action ID', [self.className]);
  end;

  fActionId := anActionId;
end;

{ TPIActionDown }

constructor TPIActionDown.create(const anActionId: string);
begin
  inherited create;

  if (anActionId = '') then
  begin
    raise EArgumentException.createFmt('(%s) Expected a non-null string for the action ID', [self.className]);
  end;

  fActionid := anActionId;
end;

{ TPIActionUp }

constructor TPIActionUp.create(const anActionId: string);
begin
  inherited create;

  if (anActionId = '') then
  begin
    raise EArgumentException.createFmt('(%s) Expected a non-null string for the action ID', [self.className]);
  end;

  fActionId := anActionId;
end;

{ TPIListChanged }

constructor TPIListChange.create(const aListId: string);
begin
  inherited create;

  if (aListId = '') then
  begin
    raise EArgumentException.createFmt('(%s) Expected a non-null string for the list ID', [self.className]);
  end;

  fListId := aListId;
end;

{ TPIBroadcast }

constructor TPIBroadcast.create(const anEventName: string);
begin
  inherited create;

  if (anEventName = '') then
  begin
    raise EArgumentException.createFmt('(%s) Expected a non-null string for the event name', [self.className]);
  end;


  fEventName := anEventName;
end;

{ TPIConnectorChange }

constructor TPIConnectorChange.create(const aConnectorId: string);
begin
  inherited create;

  if (aConnectorId = '') then
  begin
    raise EArgumentException.createFmt('(%s) Expected a non-null string for the connector ID', [self.className]);
  end;

  fConnectorId := aConnectorId;
end;

end.
