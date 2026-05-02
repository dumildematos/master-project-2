#include <Arduino.h>

#if !defined(ESP32)
#error "You are NOT compiling for ESP32. Select XIAO_ESP32S3."
#endif

#include <BLEDevice.h>

void setup() {
  Serial.begin(115200);
  delay(1000);

  BLEDevice::init("SENTIO TEST");

  Serial.println("BLE started");
}

void loop() {}

esp32-s2 wroom