#include <WiFi.h>

const char* ssid = "MV-DC-Test"; 
const char* password = "Pass12345!";   
const char* serverIP = "10.10.21.215";     
const uint16_t serverPort = 8888;

WiFiClient client;

int PulseSensorPurplePin = D0; 
int GSRSensorPin = D1; 

int Signal;        
int MappedSignal;  
int gsrValue;    
int Threshold = 500; 
int BPM;

unsigned long lastBeatTime = 0; 
bool pulseDetected = false;

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  Serial.print("Connecting to Wi-Fi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWi-Fi connected.");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());

  connectToServer();
}

void connectToServer() {
  if (!client.connect(serverIP, serverPort)) {
    Serial.println("Connection to server failed.");
  } else {
    Serial.println("Connected to server.");
  }
}

void loop() {
  if (!client.connected()) {
    Serial.println("Disconnected from server. Reconnecting...");
    connectToServer();
    delay(1000);
    return;
  }

  gsrValue = analogRead(GSRSensorPin); 
  Signal = analogRead(PulseSensorPurplePin); 
  MappedSignal = map(Signal, 0, 4095, 0, 1023);

  if (MappedSignal > Threshold) {
    if (!pulseDetected) {
      pulseDetected = true;
      unsigned long currentTime = millis();

      if (lastBeatTime > 0) {
        unsigned long timeDiff = currentTime - lastBeatTime;
        BPM = 60000 / timeDiff;
      }

      lastBeatTime = currentTime;
    }
  } else {
    pulseDetected = false;
  }

  String data = String(gsrValue) + " " + String(MappedSignal) + " " + String(BPM) + "\n";
  client.print(data);
  Serial.print(data);

  delay(50);
}
