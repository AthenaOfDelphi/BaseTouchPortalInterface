unit StreamHelperTouchPortalInterface;

interface

uses
  System.Classes,
  System.SysUtils,
  System.JSON,
  WinAPI.Windows,
  WinAPI.Messages,
  CodeSiteLogging,
  StreamAutomata,
  unitMusicManager,
  unitMidiUtils,
  BaseTouchPortalInterface,
  TouchPortalInterfaceAttributes;

type
  [TPIPluginId('aodshplug_001')]
  TStreamHelperTouchPortalInterface = class(TBaseTouchPortalInterface)
  protected
    fLastMusicPosition: integer;
    fAutomata: TStreamAutomata;
    fMusicManager: TMusicManager;
    fCurrentProvider: TMusicProvider;
    fCurrentGenre: TMusicGenre;
    fCurrentAlbum: TMusicAlbum;
    fTarget: THandle;
    fMusicPlayMsg: cardinal;
    fMusicNextMsg: cardinal;
    fMusicStopMsg: cardinal;
    fMusicAddFaveMsg: cardinal;
    fMusicRemoveMsg: cardinal;
    fMusicPosChangeMsg: cardinal;
    fMusicReqMixinMsg: cardinal;
    fMusicPrevPlaylistMsg: cardinal;
    fMusicNextPlaylistMsg: cardinal;
    fShowNowPlayingMsg: cardinal;
    fMusicPlaylistChangedMsg: cardinal;
    fStateAddMessageMsg: cardinal;
    fStreamMarkerMsg: cardinal;
    fStateRemoveMessageMsg: cardinal;
    fStateClearMsg: cardinal;
    fStateTimedMessageMsg: cardinal;
    fMicStateMsg: cardinal;
    fCamStateMsg: cardinal;

    fOnPlaySong: TSASongRequestEvent;

    procedure doHandlePaired; override;

  public
    constructor create(tpPort: word = 12136; tpHost: string = '127.0.0.1');
    destructor Destroy; override;

    //------------------------------------------------------------------------------
    // Handlers

    [TPIAction('aodshplug_act_camstate')]
    procedure actionCamState(const sender: TObject; const actionId: string; const actionData: TStringList);

    [TPIAction('aodshplug_act_playsong')]
    procedure actionPlaySong(const sender: TObject; const actionId: string; const actionData: TStringList);

    [TPIAction('aodshplug_act_streammarker')]
    procedure actionStreamMarker(const sender: TObject; const actionId: string; const actionData: TStringList);

    //------------------------------------------------------------------------------
    // Connector changes

    [TPIConnectorChange('aodshplug_con_musictrackpos')]
    procedure connectorChangeMusicTrackPos(const sender: TObject; const connectorId: string; const shortId: string; const value: integer; const actionData: TStringList);

    //------------------------------------------------------------------------------
    // List changes

    [TPIListChange('aodshplug_001.aodshplug_act_playsong.provider')]
    procedure listChangePlaysongProvider(const sender: TObject; const listId: string; const actionId: string; const instanceId: string; const value: string);

    //------------------------------------------------------------------------------
    // routines to send data to TP

    procedure musicSongChanged(provider, genre, album, song, artdata: string);
    procedure musicPositionChanged(pos: integer);
    procedure musicSendPlaylists(names: TStringList);
    procedure musicPlaylistChanged(name: string);
    procedure musicRequestMixIn(enabled: boolean);
    procedure musicSendSongsForCurrentAlbum;

    procedure musicClearSongs;

    procedure sendScriptList(names: TStringList);

    //------------------------------------------------------------------------------

    // Links to other system elements
    property msgTarget: THandle read fTarget write fTarget;
    property automata: TStreamAutomata read fAutomata write fAutomata;
    property onPlaySong: TSASongRequestEvent read fOnPlaySong write fOnPlaySong;
    property musicManager: TMusicManager read fMusicManager write fMusicManager;

    //------------------------------------------------------------------------------
    // Message identifiers

    property musicPlayMsg: cardinal read fMusicPlayMsg write fMusicPlayMsg;
    property musicNextMsg: cardinal read fMusicNextMsg write fMusicNextMsg;
    property musicStopMsg: cardinal read fMusicStopMsg write fMusicStopMsg;
    property musicAddFaveMsg: cardinal read fMusicAddFaveMsg write fMusicAddFaveMsg;
    property musicRemoveMsg: cardinal read fMusicRemoveMsg write fMusicRemoveMsg;
    property musicReqMixinMsg: cardinal read fMusicReqMixinMsg write fMusicReqMixinMsg;
    property musicPosChangeMsg: cardinal read fMusicPosChangeMsg write fMusicPosChangeMsg;
    property musicPrevPlaylistMsg: cardinal read fMusicPrevPlaylistMsg write fMusicPrevPlaylistMsg;
    property musicNextPlaylistMsg: cardinal read fMusicNextPlaylistMsg write fMusicNextPlaylistMsg;
    property musicPlaylistChangedMsg: cardinal read fMusicPlaylistChangedMsg write fMusicPlaylistChangedMsg;
    property stateAddMessageMsg: cardinal read fStateAddMessageMsg write fStateAddMessageMsg;
    property stateRemoveMessageMsg: cardinal read fStateRemoveMessageMsg write fStateRemoveMessageMsg;
    property stateClearMsg: cardinal read fStateClearMsg write fStateClearMsg;
    property stateTimedMessageMsg: cardinal read fStateTimedMessageMsg write fStateTimedMessageMsg;
    property streamMarkerMsg: cardinal read fStreamMarkerMsg write fStreamMarkerMsg;
    property micStateMsg: cardinal read fMicStateMsg write fMicStateMsg;
    property camStateMsg: cardinal read fCamStateMsg write fCamStateMsg;
    property showNowPlayingMsg: cardinal read fShowNowPlayingMsg write fShowNowPlayingMsg;
  end;

implementation

uses
  IdURI,
  IdGlobal,
  formStreamHelperMain;

constructor TStreamHelperTouchPortalInterface.create(tpPort: word; tpHost: string);
begin
  inherited create(tpPort, tpHost);

  fLastMusicPosition := -1;
end;

destructor TStreamHelperTouchPortalInterface.Destroy;
begin

  inherited;
end;

procedure TStreamHelperTouchPortalInterface.doHandlePaired;
begin
  createState('aodsh_music_songlength', 'Music - Song length', '', '');
  createState('aodsh_music_songtime','Music - Song time', '', '');
  createState('aodsh_music_playlist','Music - Current playlist', '', '');
  createState('aodsh_music_provider','Music - Current provider', '', '');
  createState('aodsh_music_genre','Music - Current genre', '', '');
  createState('aodsh_music_album','Music - Current album', '', '');
  createState('aodsh_music_song','Music - Current song', '', '');
  createState('aodsh_music_artwork','Music - Album artwork', '', '');

  musicSendProviders;
  musicClearGenres;
  musicClearAlbums;
  musicClearSongs;
end;

//------------------------------------------------------------------------------
// Action handlers

procedure TStreamHelperTouchPortalInterface.actionCamState(const sender: TObject; const actionId: string; const actionData: TStringList);
begin
  if (assigned(actionData)) then
  begin
    postMessage(fTarget, fCamStateMsg, 0, LPARAM(integer(actionData.values['aodshplug_001.aodshplug_act_camstate.state'] = 'On')));
  end
  else
  begin
    logError(self, 'Missing data from cam state action');
  end;
end;

procedure TStreamHelperTouchPortalInterface.actionPlaySong(const sender: TObject; const actionId: string; const actionData: TStringList);
var
  genreName: string;
  albumName: string;
  songName: string;
begin
  if (assigned(actionData)) then
  begin
    genreName := actionData.values['aodshplug_001.aodshplug_act_playsong.genre'];
    songName := actionData.values['aodshplug_001.aodshplug_act_playsong.song'];
    albumName := actionData.values['aodshplug_001.aodshplug_act_playsong.album'];

    if (genreName <> '') and (albumName <> '') and (songName <> '') then
    begin
      // We have the info we need to pick a track
      if (assigned(fOnPlaySong)) then
      begin
        fOnPlaySong(self, genreName, albumName, songName);
      end;
    end
    else
    begin
      logError(self, format('Missing data from play song action (Genre - %s, Album - %s, Song - %s)',
        [genreName, albumName, songName]));
    end;
  end
  else
  begin
    logError(self, 'Missing data from play song action');
  end;
end;

procedure TStreamHelperTouchPortalInterface.actionStreamMarker(const sender: TObject; const actionId: string; const actionData: TStringList);
var
  markerMessage: string;
  dataStr: PString;
begin
  if (assigned(actionData)) then
  begin
    markerMessage := actionData.values['aodshplug_001.aodshplug_act_streammarker.label'];

    if (markerMessage <> '') then
    begin
      new(dataStr);
      dataStr^ := markerMessage;
      if (not postMessage(fTarget, fStreamMarkerMsg, 1, LPARAM(dataStr))) then
      begin
        dispose(dataStr);
      end;
    end
    else
    begin
      postMessage(fTarget, fStreamMarkerMsg, 0, 0);
    end;
  end
  else
  begin
    logError(self, 'Missing data from stream marker action');
  end;
end;

//------------------------------------------------------------------------------
// Connector change handlers

procedure TStreamHelperTouchPortalInterface.connectorChangeMusicTrackPos(const sender: TObject; const connectorId: string; const shortId: string; const value: integer; const actionData: TStringList);
begin
  postMessage(fTarget, fMusicPosChangeMsg, value, 0);
end;

//------------------------------------------------------------------------------
// List change handlers

procedure TStreamHelperTouchPortalInterface.listChangePlaysongProvider(const sender: TObject; const listId: string; const actionId: string; const instanceId: string; const value: string);
var
  loop: integer;
begin
  if (assigned(fCurrentProvider)) then
  begin
    if (value <> fCurrentProvider.name) then
    begin
      fCurrentProvider := nil;
    end;
  end;

  if (not assigned(fCurrentProvider)) then
  begin
    for loop := 0 to fMusicManager.providers.Count - 1 do
    begin
      if (fMusicManager.providers[loop].name = value) then
      begin
        fCurrentProvider := fMusicManager.providers[loop];
        break;
      end;
    end;
  end;

  if (assigned(fCurrentProvider)) then
  begin
    musicSendGenresForCurrentProvider;
  end
  else
  begin
    musicClearGenres;
  end;

  fCurrentGenre := nil;
  fCurrentAlbum := nil;

  musicClearAlbums;
  musicClearSongs;
end;

//------------------------------------------------------------------------------
// Data senders

procedure TStreamHelperTouchPortalInterface.sendScriptList(names: TStringList);
begin
  choiceUpdate('aodshplug_001.aodshplug_act_script.scriptname', names);
end;

procedure TStreamHelperTouchPortalInterface.musicPlaylistChanged(name: string);
begin
  stateUpdate('aodsh_music_playlist', name);
end;

procedure TStreamHelperTouchPortalInterface.musicRequestMixIn(enabled: boolean);
var
  temp: string;
begin
  if enabled then temp := 'True' else temp := 'False';
  stateUpdate('aodshplug_state_musicreqmixinenabled', temp);
end;

procedure TStreamHelperTouchPortalInterface.musicSendSongsForCurrentAlbum;
var
  songs: TStringList;
  loop: integer;
begin
  logDbg(self, 'Music send songs');

  if (assigned(fCurrentAlbum)) then
  begin
    songs := TStringList.create;
    for loop := 0 to fCurrentAlbum.songs.count - 1 do
    begin
      songs.add(stringReplace(fCurrentAlbum.songs[loop].name, '"', '\"', [rfReplaceAll]));
    end;

    choiceUpdate('aodshplug_001.aodshplug_act_playsong.song', songs);

    songs.free;
  end
  else
  begin
    musicClearSongs;
  end;
end;

procedure TStreamHelperTouchPortalInterface.musicClearSongs;
begin
  choiceUpdate('aodshplug_001.aodshplug_act_playsong.song', nil);
end;

procedure TStreamHelperTouchPortalInterface.musicSendPlaylists(names: TStringList);
begin
  choiceUpdate('aodshplug_001.aodshplug_act_selectplaylist.playlistname', names);
end;

procedure TStreamHelperTouchPortalInterface.musicSongChanged(provider, genre, album, song, artdata: string);
begin
  stateUpdate('aodsh_music_provider', provider, true, true);
  stateUpdate('aodsh_music_genre', genre, true, true);
  stateUpdate('aodsh_music_album', album, true, true);
  stateUpdate('aodsh_music_song', song, true, true);
  stateUpdate('aodsh_music_artwork', artdata, true, true);
end;

procedure TStreamHelperTouchPortalInterface.musicPositionChanged(pos: integer);
begin
  if (pos <> fLastMusicPosition) then
  begin
    connectorUpdate('aodshplug_con_musictrackpos', pos);
    fLastMusicPosition := pos;
  end;
end;

end.
