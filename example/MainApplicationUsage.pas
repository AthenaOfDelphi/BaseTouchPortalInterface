// Code to show usage within the main application

// Creation and initialisation
  fTP := TStreamHelperTouchPortalInterface.create;
  fTP.onPaired := handleTPPaired;
  fTP.onDisconnected := handleTPDisconnected;
  fTP.msgTarget := self.handle;
  fTP.musicPlayMsg := fMPPlayMessage;
  fTP.musicStopMsg := fMPStopMessage;
  fTP.musicNextMsg := fMPNextMessage;
  fTP.musicAddFaveMsg := fMPAddFavouriteMessage;
  fTP.musicRemoveMsg := fMPRemoveFromAllMessage;
  fTP.musicReqMixinMsg := fRequestMixInEnabledStateMessage;
  fTP.musicPosChangeMsg := fMPChangePositionMessage;
  fTP.musicNextPlaylistMsg := fMPNextPlaylist;
  fTP.musicPrevPlaylistMsg := fMPPreviousPlaylist;
  fTP.showNowPlayingMsg := fShowNowPlayingMessage;
  fTP.musicPlaylistChangedMsg := fPlaylistChangedMessage;
  fTP.stateAddMessageMsg := fStatusAddStateMessage;
  fTP.stateRemoveMessageMsg := fStatusRemoveStateMessage;
  fTP.stateClearMsg := fStatusClearStateMessage;
  fTP.stateTimedMessageMsg := fStatusAddTimedMessage;
  fTP.micStateMsg := fMicStateMessage;
  fTP.camStateMsg := fCamStateMessage;

  fTP.musicManager := fMusicList;
  fTP.automata := fAutomata;
  fTP.onPlaySong := handleSongRequest;

  fTP.onLog := tpLog;
  fTP.onLogDbg := tpLogDbg;
  fTP.onLogComs := tpLogComs;
  fTP.onLogError := tpLogError;
  fTP.onLogException := tpLogException;

  fTP.initialise;

  while (not fAutomata.firstCycleCompleted) do
  begin
    application.processMessages;
  end;

  fTP.start;

// Event handlers used by the interface
procedure TfrmStreamHelperMain.tpLog(sender: TObject; msg: string);
begin
  codeSite.send(csmBlue, msg);
end;

procedure TfrmStreamHelperMain.tpLogDbg(sender: TObject; msg: string);
begin
  codeSite.send(csmBlue, 'DBG>> ' + msg);
end;

procedure TfrmStreamHelperMain.tpLogComs(sender: TObject; msg: string);
begin
  codeSite.send(csmBlue, msg);
end;

procedure TfrmStreamHelperMain.tpLogError(sender: TObject; msg: string);
begin
  codeSite.send(csmError, msg);
  logErr('StreamHelperTouchPortalInterface - ' + msg);
end;

procedure TfrmStreamHelperMain.tpLogException(sender: TObject; msg: string; e: exception);
begin
  codeSite.Send(csmError, format('Exception - %s - %s (%s)', [msg, e.className, e.message]));
  logErr('StreamHelperTouchPortalInterface Exception - ' + msg + ' - ' + e.className + ' (' + e.message + ')');
end;

procedure TfrmStreamHelperMain.handleTPPaired(sender: TObject);
begin
  sendPlaylistsToTP;

  if (fMusicList.activePlaylist <> nil) then
  begin
    fTP.musicPlaylistChanged(fMusicList.activePlaylist.name);
  end
  else
  begin
    fTP.musicPlaylistChanged(PLAYLIST_ALLSONGS);
  end;

  if (fMusicSong = nil) or (not fPlaying) then
  begin
    fTP.musicSongChanged('', '', '', '', '');
    fTP.musicPlaying(false);
    fTP.musicSongLength('--:--');
    fTP.musicSongTime('--:--');
    fTP.musicPositionChanged(0);
  end
  else
  begin
    fTP.musicSongChanged(
      fMusicSong.album.provider.name,
      fMusicSong.album.genre.name,
      fMusicSong.album.name,
      fMusicSong.name,
      fMusicSong.album.touchPortalArtData);
    fTP.musicPlaying(true);
  end;
  fTP.musicRequestMixIn(chkRequestMixInEnabled.checked);
  fTP.sendScriptList(fScriptsForTP);

  if (fAutomata.knownRoutine('touchportalconnected')) then
  begin
    {$IFDEF DEBUG}codeSite.send(csmIndigo, 'Scheduling script for TP connected');{$ENDIF}
    fAutomata.queueScriptC('touchportalconnected', []);
  end
  else
  begin
    {$IFDEF DEBUG}codeSite.send(csmIndigo, 'No script for TP connected');{$ENDIF}
  end;
end;

procedure TfrmStreamHelperMain.handleTPDisconnected(sender: TObject);
begin
  if (fAutomata.knownRoutine('touchportaldisconnected')) then
  begin
    {$IFDEF DEBUG}codeSite.send(csmIndigo, 'Scheduling script for TP disconnected');{$ENDIF}
    fAutomata.queueScriptC('touchportaldisconnected', []);
  end
  else
  begin
    {$IFDEF DEBUG}codeSite.send(csmIndigo, 'No script for TP disconnected');{$ENDIF}
  end;
end;
