import 'dart:developer' as dev;
import 'dart:math';
import 'dart:typed_data';

import 'package:libserialport/libserialport.dart';
import 'package:three_dart/three_dart.dart' as THREE;

import 'package:flutter/material.dart';
import 'package:flutter_gl/flutter_gl.dart';

class OrientationWidget extends StatefulWidget {
  const OrientationWidget({Key? key}) : super(key: key);
  @override
  State<OrientationWidget> createState() => _OrientationWidgetState();
}

class _OrientationWidgetState extends State<OrientationWidget> {
  final GlobalKey _widgetKey = GlobalKey();
  late FlutterGlPlugin flutterGlPlugin;

  THREE.WebGLRenderer? renderer;

  late THREE.WebGLRenderTarget renderTarget;
  late THREE.Scene scene;
  late THREE.Camera camera;
  late THREE.Mesh cube;

  int? fboId;
  double dpr = 1.0;
  late double width;
  late double height;

  Size? screenSize;

  dynamic sourceTexture;
  dynamic defaultFramebuffer;
  dynamic defaultFramebufferTexture;

  @override
  void initState() {
    super.initState();
    flutterGlPlugin = FlutterGlPlugin();
    WidgetsBinding.instance!.addPostFrameCallback((_) => initSize());
  }

  Future<void> initPlatformState() async {
    width = screenSize!.width;
    height = screenSize!.height;

    Map<String, dynamic> _options = {
      "antialias": true,
      "alpha": false,
      "width": width.toInt(),
      "height": height.toInt(),
      "dpr": dpr
    };

    await flutterGlPlugin.initialize(options: _options);
    await setup();
  }

  setup() async {
    await flutterGlPlugin.prepareContext();

    setupDefaultFBO();
    sourceTexture = defaultFramebufferTexture;
    initScene();
    setState(() {});
  }

  initSize() async {
    screenSize = _widgetKey.currentContext!.size;
    await initPlatformState();
  }

  initRenderer() {
    Map<String, dynamic> _options = {
      "width": width,
      "height": height,
      "gl": flutterGlPlugin.gl,
      "antialias": true,
      "canvas": flutterGlPlugin.element
    };
    renderer = THREE.WebGLRenderer(_options);
    renderer!.setPixelRatio(dpr);
    renderer!.setSize(width, height, false);
    renderer!.shadowMap.enabled = false;

    var pars = THREE.WebGLRenderTargetOptions({
      "minFilter": THREE.LinearFilter,
      "magFilter": THREE.LinearFilter,
      "format": THREE.RGBAFormat
    });
    renderTarget = THREE.WebGLRenderTarget(
        (width * dpr).toInt(), (height * dpr).toInt(), pars);
    renderTarget.samples = 4;
    renderer!.setRenderTarget(renderTarget);
    sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget);
  }

  initScene() {
    initRenderer();
    initPage();
  }

  initPage() async {
    scene = THREE.Scene();
    scene.background = THREE.Color(0xcccccc);
    scene.fog = THREE.FogExp2(0xcccccc, 0.002);

    camera = THREE.PerspectiveCamera(60, width / height, 1, 2000);
    camera.position.set(0, 200, 300);
    camera.lookAt(THREE.Vector3(0, 0, 0));

    scene = THREE.Scene();
    scene.background = THREE.Color(0xa0a0a0);
    var light = THREE.AmbientLight(0x404040); // soft white light
    scene.add(light);
    //scene.fog = THREE.Fog(0xa0a0a0, 200, 1000);

    /*var hemiLight = THREE.HemisphereLight(0xffffff, 0x444444);
    hemiLight.position.set(0, 200, 0);
    scene.add(hemiLight);*/

    var dirLight = THREE.DirectionalLight(0xffffff);
    dirLight.position.set(100, 200, 100);
    dirLight.lookAt(THREE.Vector3(0, 0, 0));
    scene.add(dirLight);

    //scene.add(THREE.CameraHelper(dirLight.shadow!.camera));

    var meshx = THREE.Mesh(THREE.PlaneGeometry(1, 1),
        THREE.MeshPhongMaterial({"color": 0x999999, "emissive": 0xFFFFFFFF}));
    meshx.rotation.x = -THREE.Math.PI / 2;
    meshx.position.y = -101;
    //mesh.receiveShadow = true;
    scene.add(meshx);

    // ground
    var mesh = THREE.Mesh(THREE.PlaneGeometry(2000, 2000),
        THREE.MeshPhongMaterial({"color": 0x999999, "emissive": 0xFFFFFFFF}));
    mesh.rotation.x = -THREE.Math.PI / 2;
    mesh.position.y = -100;
    //mesh.receiveShadow = true;
    scene.add(mesh);

    var grid = THREE.GridHelper(2000, 20, 0x000000, 0x000000);
    grid.material.opacity = 0.2;
    grid.position.y = -100;
    grid.material.transparent = true;
    scene.add(grid);

    var geometry = THREE.BoxGeometry(100, 25, 50);
    var material = THREE.MeshPhongMaterial({"color": 0xff0000});
    cube = THREE.Mesh(geometry, material);
    cube.position.set(0, 0, 0);
    cube.autoUpdate = true;
    scene.add(cube);

    animate();

    connectToArduino();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    dpr = mq.devicePixelRatio;

    return Column(
      children: [
        Expanded(
            child: Container(
                key: _widgetKey,
                color: Colors.black,
                child: Builder(builder: (BuildContext context) {
                  return flutterGlPlugin.isInitialized
                      ? Texture(textureId: flutterGlPlugin.textureId!)
                      : Container();
                })))
      ],
    );
  }

  animate() {
    render();

    Future.delayed(const Duration(milliseconds: 40), () {
      animate();
    });
  }

  setupDefaultFBO() {
    final _gl = flutterGlPlugin.gl;
    int glWidth = (width * dpr).toInt();
    int glHeight = (height * dpr).toInt();

    defaultFramebuffer = _gl.createFramebuffer();
    defaultFramebufferTexture = _gl.createTexture();
    _gl.activeTexture(_gl.TEXTURE0);

    _gl.bindTexture(_gl.TEXTURE_2D, defaultFramebufferTexture);
    _gl.texImage2D(_gl.TEXTURE_2D, 0, _gl.RGBA, glWidth, glHeight, 0, _gl.RGBA,
        _gl.UNSIGNED_BYTE, null);
    _gl.texParameteri(_gl.TEXTURE_2D, _gl.TEXTURE_MIN_FILTER, _gl.LINEAR);
    _gl.texParameteri(_gl.TEXTURE_2D, _gl.TEXTURE_MAG_FILTER, _gl.LINEAR);

    _gl.bindFramebuffer(_gl.FRAMEBUFFER, defaultFramebuffer);
    _gl.framebufferTexture2D(_gl.FRAMEBUFFER, _gl.COLOR_ATTACHMENT0,
        _gl.TEXTURE_2D, defaultFramebufferTexture, 0);
  }

  render() async {
    final _gl = flutterGlPlugin.gl;

    renderer!.render(scene, camera);

    _gl.finish();

    await flutterGlPlugin.updateTexture(sourceTexture);
  }

  //late SerialPortReader reader;
  connectToArduino() async {
    final name = SerialPort.availablePorts.first;
    final port = SerialPort(name);
    final euler = THREE.Euler();
    port.config.baudRate = 115200;
    port.config.bits = 8;
    port.config.parity = 0;
    port.config.stopBits = 1;
    port.config.dtr = 1;

    if (port.openReadWrite()) {
      print("port open");
      var reader = SerialPortReader(port);
      var buffer = Uint8List(32);
      var counter = 0;
      reader.stream.listen((data) {
        for (var byte in data) {
          buffer[counter++] = byte;
          if (counter == 12) {
            counter = 0;
            var floatList = buffer.buffer.asFloat32List();

            cube.rotation.set(floatList[2], floatList[0], floatList[1]);
          }
        }
        //
      });
    } else {
      print("port error");
    }
  }
}
