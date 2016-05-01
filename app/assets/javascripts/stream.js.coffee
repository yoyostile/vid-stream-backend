class @SignalingChannel
  socket = io('http://ngnsignaling.r4r3.me')

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
    url: 'turn:ec2-52-31-83-4.eu-west-1.compute.amazonaws.com',
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

    @conn.onicecandidate = (e) =>
      if e.candidate && @user
        @signalingChannel.send @user, JSON.stringify({ "candidate": e.candidate })

  getConnection: ->
    @conn

  createAnswer: (user) =>
    localDescCreated = (desc) =>
      @.conn.setLocalDescription desc
      @.signalingChannel.send user, JSON.stringify({ "sdp": desc })
      console.log desc

    @.conn.createAnswer localDescCreated, (e) ->
      console.log 'answer: ' + e

  createOffer: (user) =>
    gotDescription = (desc) =>
      @.conn.setLocalDescription desc
      @.signalingChannel.send user, JSON.stringify({ "sdp": desc })

    @.conn.createOffer gotDescription, (error) ->
      console.log 'error: ' + error

  handleMessage: (msg) =>
    user = msg.user
    msg = JSON.parse(msg.message)
    console.log 'messageReceived from ' + user
    console.log msg
    if msg.sdp
      @.conn.setRemoteDescription new RTCSessionDescription(msg.sdp), =>
        if @.conn.remoteDescription.type == 'offer'
          @.createAnswer user
    else
      @.conn.addIceCandidate new RTCIceCandidate(msg.candidate)

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
      @.signalingChannel.login @.streamName
      @.videoContainer.src = URL.createObjectURL stream
      @.videoContainer.play()
      # @.conn.addStream stream
      @.stream = stream
    , (stream) ->
      console.log 'lulz error'
      console.log stream

    console.log 'Adding join Listener to Socket'
    @signalingChannel.getSocket().on 'join', (user) =>
      console.log 'join: ' + user
      @.peers << new Peer @.signalingChannel, @.stream, user


  joinStream: ->
    @signalingChannel.login @.streamName
    socket = @signalingChannel.getSocket()
    broadcaster = new Peer @signalingChannel

    socket.on 'joined', (msg) ->
      console.log 'joined: Join successful'
      console.log msg

    broadcaster.getConnection().onaddstream = (e) =>
      console.log e
      @.videoContainer.src = URL.createObjectURL e.stream
      @.videoContainer.play()

    true
