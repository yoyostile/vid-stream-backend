class @SignalingChannel
  #socket = io('https://ngnsignaling.r4r3.me')
  socket = io('http://localhost:5000')

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
    password: 'johannes'
  }

  constructor: ->
    config = {
      iceServers: [Connection.STUN, Connection.TURN]
    }
    @conn = new webkitRTCPeerConnection config

  getConnection: ->
    @conn


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
        @signalingChannel.send @user, JSON.stringify({ "candidate": e.candidate })

  getConnection: ->
    @conn

  createAnswer: (user) =>
    localDescCreated = (desc) =>
      @conn.setLocalDescription desc
      @signalingChannel.send user, JSON.stringify({ "sdp": desc })
      console.log desc

    @conn.createAnswer localDescCreated, (e) ->
      console.log 'answer: ' + e

  createOffer: (user) =>
    gotDescription = (desc) =>
      @conn.setLocalDescription desc
      @signalingChannel.send user, JSON.stringify({ "sdp": desc })

    @conn.createOffer gotDescription, (error) ->
      console.log 'error: ' + error

  handleMessage: (msg) =>
    user = msg.user
    @connectedUser = user if @connectedUser == undefined
    msg = JSON.parse(msg.message)
    console.log 'messageReceived from ' + user
    console.log msg
    console.log 'connection status ' + @conn.iceConnectionState
    console.log 'Stream connected? ' + @streamConnected
    if user == @connectedUser
      if msg.sdp
        @conn.setRemoteDescription new RTCSessionDescription(msg.sdp), =>
          if @conn.remoteDescription.type == 'offer'
            @user = user
            @createAnswer user
            @streamConnected = true
      else if msg.candidate
        console.log 'added candidate for ' + user
        @conn.addIceCandidate new RTCIceCandidate(msg.candidate)

class @Stream
  constructor: (streamName) ->
    @signalingChannel = new SignalingChannel
    @streamName = streamName

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
      console.log 'lulz error'
      console.log stream

    console.log 'Adding join Listener to Socket'
    @signalingChannel.getSocket().on 'join', (user) =>
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
      console.log e
      @videoContainer.src = URL.createObjectURL e.stream
      @videoContainer.play()

      @signalingChannel.getSocket().on 'join', (user) =>
        console.log 'join: ' + user
        @peers << new Peer @signalingChannel, e.stream.clone(), user

    true
