import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter_phoenix/flutter_phoenix.dart';

void main() {
  runApp(Phoenix(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garbage Monitoring',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: MapView(),
    );
  }
}

class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  CameraPosition _initialLocation = CameraPosition(target: LatLng(0.0, 0.0));
  GoogleMapController mapController;
  final Geolocator _geolocator = Geolocator();
  Position currentPosition;
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  String apikey = "5b3ce3597851110001cf6248bafafcec515946edb5db8b7ca5818e2b";
  Set<Polyline> polylines = {};
  List<LatLng> polyPoints = [];
  Map<MarkerId, LatLng> locations = <MarkerId, LatLng>{};
  Map<MarkerId, double> distances = <MarkerId, double>{};
  MarkerId closestmarker;
  bool isEnabled = true ;

  getCurrentLocation() async {
    await _geolocator
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        currentPosition = position;
        print('CURRENT POS: $currentPosition');
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 18.0,
            ),
          ),
        );
      });
    }).catchError((e) {
      print(e);
    });
  }


  Future<double> calculatingdistance(lat1, lon1, lat2, lon2) async{
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  mappingdistancestocurrentlocation(LatLng currentreferenceposition) async{
    for (int i = 0; i < locations.length; i++)  {
      var distance =  await calculatingdistance(
          currentreferenceposition.latitude,currentreferenceposition.longitude,
          locations.values.toList()[i].latitude,locations.values.toList()[i].longitude );
      distances[locations.keys.toList()[i]] = distance;
    }
  }

  closestmarkerlocation(LatLng currentreferenceposition) async {
    await mappingdistancestocurrentlocation(currentreferenceposition);
    if (currentreferenceposition !=
        LatLng(currentPosition.latitude, currentPosition.longitude)) {
      locations.removeWhere((k, v) => v == currentreferenceposition);
    }
    Map.fromEntries(distances.entries.toList()
      ..sort((e1, e2) => e1.value.compareTo(e2.value)));
    List<MarkerId> markerIds = distances.keys.toList();
    for (int i = 0; i < markerIds.length; i++) {
      if (distances[markerIds[i]] != 0.0 &&
          locations.containsKey(markerIds[i])) {
        closestmarker = markerIds[i];
      }
    }
    return locations[closestmarker];
  }

  populatebins() async {
    await Firestore.instance
        .collection('Garbage Bins - Locations')
        .getDocuments()
        .then(
      (docs) {
        if (docs.documents.isNotEmpty) {
          setState(() {
            for (int i = 0; i < docs.documents.length; i++) {
              _add(docs.documents[i].data);
              if(docs.documents[i].data['Status'] >= 75.0) {
                locations[MarkerId(docs.documents[i].data['Name'])] = LatLng(
                  docs.documents[i].data['Location'].latitude,
                  docs.documents[i].data['Location'].longitude,
                );
              }
            }
          });
        }
      },
    );
    return locations;
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))
        .buffer
        .asUint8List();
  }
//for resizing the icons used as marker.

   _add(data) async {
     double distance =  await calculatingdistance(currentPosition.latitude,currentPosition.longitude, data['Location'].latitude,
      data['Location'].longitude,);
     var distanceinmeters = distance*1000;
     var markerIdVal = data['Name'];
    final MarkerId markerId = MarkerId(markerIdVal);
    Uint8List icon;
    if(data['Status'] >= 75){
      icon = await getBytesFromAsset('android/assets/bin-green.png', 75);
    }else{
      icon = await getBytesFromAsset('android/assets/bin-red.jpg', 75);
    }
    final Uint8List markerIcon = icon;
    final Marker marker = Marker(
      markerId: markerId,
      position: LatLng(
        data['Location'].latitude,
        data['Location'].longitude,
      ),
      icon: BitmapDescriptor.fromBytes(markerIcon),
      infoWindow: InfoWindow(title: distanceinmeters.round().toString(), snippet: 'meters'),
    );
    setState(() {
      markers[markerId] = marker;
    });
  }

  Future getData(LatLng source, LatLng destination) async{
    http.Response response = await http.get('https://api.openrouteservice.org/v2/directions/driving-car?api_key=5b3ce3597851110001cf6248bafafcec515946edb5db8b7ca5818e2b&start=${source.longitude},${source.latitude}&end=${destination.longitude},${destination.latitude}');
    if(response.statusCode == 200) {
      String data = response.body;
      return jsonDecode(data);
    }
    else{
      print(response.statusCode);
    }
  }

  getJsonData(LatLng sourceposition, LatLng destinationposition) async {
    try {
      // getData() returns a json Decoded data
      var data = await getData(sourceposition, destinationposition);
      LineString ls = LineString(data['features'][0]['geometry']['coordinates']);
      for (int i = 0; i < ls.lineString.length; i++) {
        polyPoints.add(LatLng(ls.lineString[i][1], ls.lineString[i][0]));
      }
      setPolyLines();
    }
    catch(e){
      print(e);
    }

  }

  setPolyLines() {
    Polyline polyline = Polyline(
      polylineId: PolylineId("polyline"),
      color: Colors.blue,
      visible: true,
      width: 8,
      points: polyPoints,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );
    polylines.add(polyline);
    setState(() {});
  }


  finalcode() async{

    LatLng dest = await closestmarkerlocation(LatLng(currentPosition.latitude,currentPosition.longitude));
    await getJsonData(LatLng(currentPosition.latitude,currentPosition.longitude),
        dest);
    while(locations.length > 1){
      LatLng dest1 = await closestmarkerlocation(dest);
      await getJsonData(dest,
          dest1);
      dest = dest1;
    }
  }

  @override
  void initState() {
    super.initState();
    getCurrentLocation();

  }

  @override
  Widget build(BuildContext context) {

    var width = MediaQuery.of(context).size.width;

    return Container(
      width: width,
      child: Scaffold(
        appBar: AppBar(
          title: Center(child: Text('GARBAGE MONITORING', style: TextStyle(fontSize: 20, color: Colors.white))),
        ),
        body: Stack(
          children: <Widget>[
            GoogleMap(
              initialCameraPosition: _initialLocation,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
              markers: Set<Marker>.of(markers.values),
              polylines: polylines,
            ),
            Positioned(
              bottom: 80.0,
              left: 10.0,
              child: ClipOval(
                child: Material(
                  color: Colors.white70, // button color
                  child: InkWell(
                    splashColor: Colors.white70, // inkwell color
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.my_location),
                    ),
                    onTap: () {
                      setState(() {
                        getCurrentLocation();
                      });
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 30.0,
              left: 80.0,
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 220.0,
                      height: 70.0,
                      child: RaisedButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.0),
                          side: BorderSide(color: Colors.green),
                        ),
                        onPressed: () async {
                          if (isEnabled) {
                            Map<MarkerId,
                                LatLng> Locations = await populatebins();
                            setState(() {
                              locations = Locations;
                              print(locations);
                              finalcode();
                            });
                            isEnabled = false;
                          }
                        },
                        child: Center(
                          child: const Text('GET ROUTE',
                              style: TextStyle(fontSize: 20, color: Colors.white)),
                        ),
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(
                      height: 10.0,
                    ),
                    SizedBox(
                      width: 220.0,
                      height: 70.0,
                      child: RaisedButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.0),
                          side: BorderSide(color: Colors.red),
                        ),
                        onPressed: () async {
                          if (isEnabled == false) {
                            Phoenix.rebirth(context);
                            setState(() {

                            });
                            isEnabled = true;
                          }
                        },
                        child: Center(
                          child: const Text('RESET',
                              style: TextStyle(fontSize: 20, color: Colors.white)),
                        ),
                        color: Colors.redAccent,
                      ),
                    )
                  ],
                ),
              ),
            )
          ],

        ),
      ),
    );
  }
}

class LineString {
  LineString(this.lineString);
  List<dynamic> lineString;
}