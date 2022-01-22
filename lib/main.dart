// @dart=2.9
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_sensors/flutter_sensors.dart';
import 'package:http/http.dart' as http; // for making HTTP calls
import 'dart:convert'; // for converting JSON
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:uuid/uuid.dart'; // for http headers

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rail Track Monitoring System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class LiveData {
  LiveData(this.time, this.speed);
  final int time;
  final num speed;
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  var uuid = const Uuid();
  Map<String, dynamic> deviceData;
  static final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  String startTime;
  bool startRecoding = false;
  String thresholdMessage = "";
  int jerkCounter = 0;
  int xAxisJerk = 0;
  int yAxisJerk = 0;
  int zAxisJerk = 0;
  int xAxisThreshold = 20;
  int yAxisThreshold = 20;
  int zAxisThreshold = 20;
  List<LiveData> xChartData = [];
  List<LiveData> yChartData = [];
  List<LiveData> zChartData = [];
  int time = 0;
  int incrementTimeValue = 5;
  geo.Position currentCoordinates = new geo.Position();
  Map<String, dynamic> totalJerkRecordedData = {
    "xAxis": [],
    "yAxis": [],
    "zAxis": [],
    "totalJerks": 0,
    "totalTime": 0,
    "modelName": "",
    "deviceId": "",
    "macAddress": "",
    "tripId": "" // create random
  };

  Map<String, dynamic> totalDetailedRecordedData = {
    "xAxis": [],
    "yAxis": [],
    "zAxis": [],
    "totalJerks": 0,
    "totalTime": 0,
    "modelName": "",
    "deviceId": "",
    "macAddress": "",
    "tripId": "" // create random
  };

  Stream<geo.Position> get positionStream => geo.Geolocator().getPositionStream(new geo.LocationOptions(timeInterval: 1)).asBroadcastStream();

  @override
  void initState() {
    xChartData = [];
    yChartData = [];
    zChartData = [];
    // TODO: implement initState
    super.initState();
    getCurrentLocationSMSPermission();

//  store device info in packets
  getDeviceInfo();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return Scaffold(
        floatingActionButton: FloatingActionButton(
          child: Icon(
            !startRecoding ? Icons.play_arrow : Icons.stop,
            color: Colors.white,
          ),
          onPressed: () async {
            setState(() {
              startRecoding = !startRecoding;
              if(!startRecoding){
                jerkCounter = 0;
                xAxisJerk = 0;
                yAxisJerk = 0;
                zAxisJerk = 0;
                xAxisThreshold = 20;
                yAxisThreshold = 20;
                zAxisThreshold = 20;
                xChartData = [];
                yChartData = [];
                zChartData = [];
                time = 0;

                totalJerkRecordedData["xAxis"] = [];
                totalJerkRecordedData["yAxis"] = [];
                totalJerkRecordedData["zAxis"] = [];
                totalJerkRecordedData["totalJerks"] = 0;
                totalJerkRecordedData["totalTime"] = 0;

                totalDetailedRecordedData["xAxis"] = [];
                totalDetailedRecordedData["yAxis"] = [];
                totalDetailedRecordedData["zAxis"] = [];
                totalDetailedRecordedData["totalJerks"] = 0;
                totalDetailedRecordedData["totalTime"] = 0;

              } else {
//          journey started
                startTime = DateTime.now().toUtc().toString();
                //  generate random trip id
                totalDetailedRecordedData["tripId"] = uuid.v1();
                totalJerkRecordedData["tripId"] = totalDetailedRecordedData["tripId"];

                downloadJerkReportLocally(jsonEncode(totalJerkRecordedData), totalJerkRecordedData["tripId"], startTime);
                downloadDetailedReportLocally(jsonEncode(totalDetailedRecordedData), totalDetailedRecordedData["tripId"], startTime);
              }
            });
          },
        ),
        appBar: AppBar(
          title: const Center(child: Text("Jerk Detector")),
        ),
        body: FutureBuilder(
            future: SensorManager().sensorUpdates(
              sensorId: Sensors.ACCELEROMETER,
              interval: Duration(milliseconds: incrementTimeValue),
            ),
            builder: (context, AsyncSnapshot<Stream<SensorEvent>> sensorData) {
              return sensorData.data == null
                  ? Container()
                  : StreamBuilder(
                  stream: sensorData.data,
                  builder: (context,
                      AsyncSnapshot<SensorEvent> streamedSensorData) {
                    if (streamedSensorData.data == null) {
                      return Container();
                    } else {
                      return Center(
                        child: !startRecoding ? Text("Start Recording") :  SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              chart(streamedSensorData.data),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  thresholdMessage,
                                  style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w900),
                                ),
                              ),
                              Table(
                                border: TableBorder.all(width: 2.0, color: Colors.blueAccent, style: BorderStyle.solid),
                                children: [
                                  const TableRow(children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Center(child: Text("Axis")),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Center(child: Text("Acc. Value")),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Center(child: Text("Jerks")),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Center(child: Text("Threshold")),
                                    ),
                                  ]),
                                  axisRow(streamedSensorData.data, "X-Axis"),
                                  axisRow(streamedSensorData.data, "Y-Axis"),
                                  axisRow(streamedSensorData.data, "Z-Axis"),

                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text("Total Jerks:\n" + jerkCounter.toString(), textAlign: TextAlign.center, style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w900),),
                              ),
//                                  downloadReport()
                            ],
                          ),
                        ),
                      );
                    }
                  });
            }));
  }

  TableRow axisRow(SensorEvent streamedSensorData, String axis){
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text("$axis : ", style: const TextStyle(fontSize: 15.0),
              ),
              Icon(Icons.timeline, color: axis == "X-Axis" ? Colors.red : axis == "Y-Axis" ? Colors.green : Colors.blue,)
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Text( axis == "X-Axis" ?  streamedSensorData.data[0].toStringAsFixed(2) : axis == "Y-Axis" ? streamedSensorData.data[1].toStringAsFixed(2) : streamedSensorData.data[2].toStringAsFixed(2),
                //trim the asis value to 2 digit after decimal point
                style: const TextStyle(fontSize: 20.0)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
              child: axis == "X-Axis" ? Text(xAxisJerk.toString(),
                  //trim the asis value to 2 digit after decimal point
                  style: const TextStyle(fontSize: 20.0)) : axis == "Y-Axis" ?
              Text( yAxisJerk.toString() ,
                  //trim the asis value to 2 digit after decimal point
                  style: const TextStyle(fontSize: 20.0)) :
              Text( zAxisJerk.toString(),
                  //trim the asis value to 2 digit after decimal point
                  style: const TextStyle(fontSize: 20.0))
          ),
        ),
        GestureDetector(
          onTap: (){
            showDialog(context: context, builder: (context) => thresholdDialog(axis));
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(axis == "X-Axis" ? xAxisThreshold.toString() : axis == "Y-Axis" ? yAxisThreshold.toString() : zAxisThreshold.toString(), style: const TextStyle(fontSize: 20.0)),
                const Icon(Icons.edit)
              ],
            )),
          ),
        ),
      ],
    );
  }

  Widget chart(SensorEvent streamedSensorData) {
    return SfCartesianChart(
        series: <LineSeries<LiveData, int>>[
          LineSeries<LiveData, int>(
            dataSource: updateDataSource( "X-Axis", streamedSensorData.data[0]),
            color: const Color.fromRGBO(
                192, 108, 132, 1),
            xValueMapper: (LiveData sales, _) =>
            sales.time,
            yValueMapper: (LiveData sales, _) =>
            sales.speed,
          ),
          LineSeries<LiveData, int>(
              dataSource: updateDataSource( "Y-Axis", streamedSensorData.data[1]),
              color: const Color.fromRGBO(
                  192, 108, 132, 1),
              xValueMapper: (LiveData sales, _) => sales.time,
              yValueMapper: (LiveData sales, _) => sales.speed,
              pointColorMapper: (_, color) => Colors.green
          ),
          LineSeries<LiveData, int>(
              dataSource: updateDataSource("Z-Axis", streamedSensorData.data[2],),
              color: const Color.fromRGBO(192, 108, 132, 1),
              xValueMapper: (LiveData sales, _) => sales.time,
              yValueMapper: (LiveData sales, _) => sales.speed,
              pointColorMapper: (_, color) => Colors.blue
          )
        ],
        primaryXAxis: NumericAxis(
            majorGridLines: MajorGridLines(width: 0),
            edgeLabelPlacement: EdgeLabelPlacement.shift,
            interval: 3,
            title: AxisTitle(text: 'Time (milliseconds)')),
        primaryYAxis: NumericAxis(axisLine: const AxisLine(width: 0), interval: 10.0, visibleMinimum: -10, majorTickLines: const MajorTickLines(size: 0), title: AxisTitle(text: 'Jerk (g)')));
  }

  Widget thresholdDialog(String axis){
    return AlertDialog(
      title: Container(
        height: 150,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextFormField(
              initialValue: axis == "X-Axis" ? xAxisThreshold.toString() : axis == "Y-Axis" ?  yAxisThreshold.toString() : zAxisThreshold.toString(),
              onChanged: (value) => {
                axis == "X-Axis" ? xAxisThreshold =  int.parse(value) : axis == "Y-Axis" ?  yAxisThreshold =  int.parse(value) : zAxisThreshold=  int.parse(value)
              },
              decoration: InputDecoration(
                  hintText: "Enter $axis Threshold Value"
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(5.0),
              child: RaisedButton(
                  color: Colors.blue,
                  child: Text("Save", style: TextStyle(color: Colors.white),),
                  onPressed: () => {
                    Navigator.pop(context),
                    setState(() => {
                    })
                  }),
            )
          ],
        ),
      ),
    );
  }

  getSensor() async {
    bool accelerometerAvailable =
    await SensorManager().isSensorAvailable(Sensors.ACCELEROMETER);
  }

  List<LiveData> updateDataSource(String axis, double value) {
    if(axis == "X-Axis") {
      xChartData.add(LiveData(time = time+incrementTimeValue, value));
      if (xChartData.length > 15) {
        xChartData.removeAt(0);
      }
      if (value > xAxisThreshold) {
        xAxisJerk++;
        jerkCounter++;
        totalJerkRecordedData["xAxis"].add({
          "jerkAxis": "X",
          "jerkId": xAxisJerk,
          "jerkValue": value,
          "jerkTime": time,
          "jerkThreshold": xAxisThreshold,
          "latitude": currentCoordinates.latitude.toString(),
          "longitude": currentCoordinates.longitude.toString(),
        });

        sendMail({
          "jerkAxis": "X",
          "jerkId": xAxisJerk.toString(),
          "jerkValue": value.toString(),
          "jerkTime": time.toString(),
          "modelName": totalJerkRecordedData["modelName"].toString(),
          "deviceId": totalJerkRecordedData["deviceId"].toString(),
          "tripId": totalJerkRecordedData["tripId"].toString(),
          "jerkThreshold": xAxisThreshold.toString(),
          "latitude": currentCoordinates.latitude.toString(),
          "longitude": currentCoordinates.longitude.toString(),
        });
      }
      totalJerkRecordedData["totalJerks"] = jerkCounter;
      totalJerkRecordedData["totalTime"] = time;

//      saving every reading from sensor
      totalDetailedRecordedData["xAxis"].add({
        "jerkAxis": "X",
        "jerkId": xAxisJerk,
        "jerkValue": value,
        "jerkTime": time,
        "jerkThreshold": xAxisThreshold,
        "latitude": currentCoordinates.latitude.toString(),
        "longitude": currentCoordinates.longitude.toString(),
      });


      if(time % 6000 == 0){
        downloadDetailedReportLocally(jsonEncode(totalDetailedRecordedData), totalDetailedRecordedData["tripId"], startTime);
      }

      return xChartData;

    } else if(axis == "Y-Axis") {
      yChartData.add(LiveData(time = time+incrementTimeValue, value));
      if (yChartData.length > 15) {
        yChartData.removeAt(0);
      }
      if (value > yAxisThreshold) {
        yAxisJerk++;
        jerkCounter++;
        totalJerkRecordedData["yAxis"].add({
          "jerkId": yAxisJerk,
          "jerkAxis": "Y",
          "jerkThreshold": yAxisThreshold,
          "jerkValue": value,
          "jerkTime": time,
          "latitude": currentCoordinates.latitude.toString(),
          "longitude": currentCoordinates.longitude.toString(),      });

        sendMail({
          "jerkId": yAxisJerk.toString(),
          "jerkAxis": "Y",
          "jerkThreshold": yAxisThreshold.toString(),
          "jerkValue": value.toString(),
          "jerkTime": time.toString(),
          "modelName": totalJerkRecordedData["modelName"].toString(),
          "deviceId": totalJerkRecordedData["deviceId"].toString(),
          "tripId": totalJerkRecordedData["tripId"].toString(),
          "latitude": currentCoordinates.latitude.toString(),
          "longitude": currentCoordinates.longitude.toString(),});
      }
      totalJerkRecordedData["totalJerks"] = jerkCounter;
      totalJerkRecordedData["totalTime"] = time;

      totalDetailedRecordedData["yAxis"].add({
        "jerkId": yAxisJerk,
        "jerkAxis": "Y",
        "jerkThreshold": yAxisThreshold,
        "jerkValue": value,
        "jerkTime": time,
        "latitude": currentCoordinates.latitude.toString(),
        "longitude": currentCoordinates.longitude.toString(),      });

      if(time % 6000 == 0){
        downloadDetailedReportLocally(jsonEncode(totalDetailedRecordedData), totalDetailedRecordedData["tripId"], startTime);
      }
      return yChartData;
    } else {
      zChartData.add(LiveData(time = time+incrementTimeValue, value));
      if (zChartData.length > 15) {
        zChartData.removeAt(0);
      }
      if (value > zAxisThreshold) {
        zAxisJerk++;
        jerkCounter++;
        totalJerkRecordedData["zAxis"].add({
          "jerkId": zAxisJerk,
          "jerkAxis": "Z",
          "jerkValue": value,
          "jerkTime": time,
          "jerkThreshold": zAxisThreshold,
          "latitude": currentCoordinates.latitude.toString(),
          "longitude": currentCoordinates.longitude.toString(),        });

        sendMail({
          "jerkId": zAxisJerk.toString(),
          "jerkAxis": "Z",
          "jerkValue": value.toString(),
          "jerkTime": time.toString(),
          "modelName": totalJerkRecordedData["modelName"].toString(),
          "deviceId": totalJerkRecordedData["deviceId"].toString(),
          "tripId": totalJerkRecordedData["tripId"].toString(),
          "jerkThreshold": zAxisThreshold.toString(),
          "latitude": currentCoordinates.latitude.toString(),
          "longitude": currentCoordinates.longitude.toString(),        });
      }
      totalJerkRecordedData["totalJerks"] = jerkCounter;
      totalJerkRecordedData["totalTime"] = time;

      totalDetailedRecordedData["zAxis"].add({
        "jerkId": zAxisJerk,
        "jerkAxis": "Z",
        "jerkValue": value,
        "jerkTime": time,
        "jerkThreshold": zAxisThreshold,
        "latitude": currentCoordinates.latitude.toString(),
        "longitude": currentCoordinates.longitude.toString(),        });

      if(time % 6000 == 0){
        downloadDetailedReportLocally(jsonEncode(totalDetailedRecordedData), totalDetailedRecordedData["tripId"], startTime);
      }
      return zChartData;
    }
  }

  getDeviceInfo() async {
    deviceData = _readAndroidBuildData(await deviceInfoPlugin.androidInfo);

    totalDetailedRecordedData["modelName"] = deviceData["model"];
    totalDetailedRecordedData["deviceId"] = deviceData["id"];

    totalJerkRecordedData["modelName"] = deviceData["model"];
    totalJerkRecordedData["deviceId"] = deviceData["id"];
  }

  Map<String, dynamic> _readAndroidBuildData(AndroidDeviceInfo build) {
    return <String, dynamic>{
      'version.securityPatch': build.version.securityPatch,
      'version.sdkInt': build.version.sdkInt,
      'version.release': build.version.release,
      'version.previewSdkInt': build.version.previewSdkInt,
      'version.incremental': build.version.incremental,
      'version.codename': build.version.codename,
      'version.baseOS': build.version.baseOS,
      'board': build.board,
      'bootloader': build.bootloader,
      'brand': build.brand,
      'device': build.device,
      'display': build.display,
      'fingerprint': build.fingerprint,
      'hardware': build.hardware,
      'host': build.host,
      'id': build.id,
      'manufacturer': build.manufacturer,
      'model': build.model,
      'product': build.product,
      'supported32BitAbis': build.supported32BitAbis,
      'supported64BitAbis': build.supported64BitAbis,
      'supportedAbis': build.supportedAbis,
      'tags': build.tags,
      'type': build.type,
      'isPhysicalDevice': build.isPhysicalDevice,
      'androidId': build.androidId,
      'systemFeatures': build.systemFeatures,
    };
  }

  sendMail(body)async{
    return await http.post(
        Uri.parse("http://15.206.73.160/api/sendEmailOnJerkDetection"),
        headers: body,
        body: body
    ).then((value) async {
      await downloadJerkReportLocally(jsonEncode(totalJerkRecordedData), totalJerkRecordedData["tripId"], startTime);
    });
  }

  getCurrentLocation(){
    geo.Geolocator().getPositionStream(new geo.LocationOptions(timeInterval: 1)).listen((position){
      currentCoordinates = position;
    });
  }

  downloadJerkReportLocally(String report, String tripId, String startTime) async {
    final directory = (await getExternalStorageDirectories(type: StorageDirectory.downloads)).first;
    final File file = File('${directory.path}/jerkReport_' + tripId + '_' + startTime + ".txt");
    await file.writeAsString('');
    await file.writeAsString(report);
  }


  downloadDetailedReportLocally(String report, String tripId, String startTime) async {
    final directory = (await getExternalStorageDirectories(type: StorageDirectory.downloads)).first;
    final File file = File('${directory.path}/detailedReport_' + tripId + '_' + startTime + ".txt");
    await file.writeAsString('');
    await file.writeAsString(report);
  }

  getCurrentLocationSMSPermission() async {

    bool locationEnabledStatus = await geo.Geolocator().isLocationServiceEnabled();
    geo.GeolocationStatus locationPermissionStatus = await geo.Geolocator().checkGeolocationPermissionStatus();

    if(locationEnabledStatus){
      getCurrentLocation();
    } else {
      showDialog(context: context, builder: (context)  => const AlertDialog(
        title: Text("Please Enable Location"),
      )).whenComplete(() => getCurrentLocationSMSPermission());
      if(locationPermissionStatus == geo.GeolocationStatus.denied){

      } else {

      }
    }
  }
}
