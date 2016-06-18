class @SignalingChannel
  socket = io('https://ngnsignaling.r4r3.me')

  send: (user, msg) ->
    socket.emit 'sendMessage', user, msg

  login: (name) ->
    socket.emit 'login', name

  getSocket: ->
    socket

class @Connection
  @STUN: {
    url: 'stun:stun.l.google.com:19302'
  }

  @TURN: {
    url: 'turn:5d3435fc-09fe-4ba6-8730-36d07924a5a0.pub.cloud.scaleway.com',
    username: 'johannes',
    credential: 'johannes',
    credentialType: 'password'
  }

  constructor: ->
    config = {
      iceServers: [Connection.STUN, Connection.TURN]
    }
    @conn = new webkitRTCPeerConnection config
    console.log @conn

  getConnection: ->
    @conn

  iceConnectionState: ->
    @conn.iceConnectionState


class @Peer
  constructor: (signalingChannel, stream, user) ->
    @signalingChannel = signalingChannel
    @stream = stream
    @user = user
    @conn = (new Connection).getConnection()
    console.log stream if stream
    @conn.addStream stream if stream
    @signalingChannel.getSocket().on 'messageReceived', @handleMessage
    @createOffer @user if @user
    @connectedUser = undefined

    @conn.onicecandidate = (e) =>
      if e.candidate && @user
        # console.log "Ice Candidate:"
        # console.log e.candidate
        @signalingChannel.send @user, JSON.stringify({ "candidate": e.candidate })

  getConnection: ->
    @conn

  createAnswer: (user) =>
    localDescCreated = (desc) =>
      @conn.setLocalDescription desc
      @signalingChannel.send user, JSON.stringify({ "sdp": desc })
      # console.log desc

    @conn.createAnswer localDescCreated, (e) ->
      console.log 'answer: '
      console.log  e

  createOffer: (user) =>
    gotDescription = (desc) =>
      @conn.setLocalDescription desc
      @signalingChannel.send user, JSON.stringify({ "sdp": desc })

    @conn.createOffer gotDescription, (error) ->
      console.log 'error: ' + error

  handleMessage: (msg) =>
    user = msg.user
    @connectedUser = user if @connectedUser == undefined
    console.log "connected to: " + @connectedUser
    msg = JSON.parse(msg.message)
    # console.log 'messageReceived from ' + user
    # console.log msg
    # console.log 'connection status ' + @conn.iceConnectionState
    # console.log 'Stream connected? ' + @streamConnected
    if user == @connectedUser
      if msg.sdp
        # console.log "SDP"
        # console.log msg.sdp
        @conn.setRemoteDescription new RTCSessionDescription(msg.sdp), =>
          if @conn.remoteDescription.type == 'offer'
            @user = user
            @createAnswer user
            @streamConnected = true
      else if msg.candidate && @conn.remoteDescription
        console.log 'added candidate for ' + user
        console.log msg.candidate
        @conn.addIceCandidate new RTCIceCandidate(msg.candidate)

class @Stream
  constructor: (streamName) ->
    @signalingChannel = new SignalingChannel
    @streamName = streamName
    @socketId = @signalingChannel.getSocket().io.engine.id
    console.log 'My ID: ' + @socketId

    @videoContainer = $('.video-container')[0]
    @peers = []

  createStream: ->
    navigator.webkitGetUserMedia {
      audio: true,
      video: true
    }, (stream) =>
      @signalingChannel.login @streamName
      @videoContainer.src = URL.createObjectURL stream
      @videoContainer.play()
      # @conn.addStream stream
      @stream = stream
    , (stream) ->
      # console.log 'lulz error'
      # console.log stream

    console.log 'Adding join Listener to Socket'
    @signalingChannel.getSocket().on 'join', (user) =>
      return if Math.random() < 0.8 && @peers.length > 0
      unless user.match @socketId
        console.log 'join: ' + user
        @peers << new Peer @signalingChannel, @stream, user


  joinStream: ->
    @signalingChannel.login @streamName
    socket = @signalingChannel.getSocket()
    broadcaster = new Peer @signalingChannel

    socket.on 'joined', (msg) ->
      console.log 'joined: Join successful'
      console.log msg

    broadcaster.getConnection().onaddstream = (e) =>
      if @videoContainer.src == ""
        @videoContainer.src = URL.createObjectURL e.stream
        @videoContainer.play()
        console.log "Offering replicated Stream"

        @signalingChannel.getSocket().on 'join', (user) =>
          unless user == @socketId
            console.log 'join: ' + user
            remoteStream = new webkitMediaStream(e.stream)
            # console.log 'stream ids'
            # console.log e.stream
            # console.log remoteStream.id
            @peers << new Peer @signalingChannel, remoteStream, user

    true
