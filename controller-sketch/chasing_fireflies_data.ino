/* 
  LILYGO Joystick, Potentiometer, Button
  Prints out X, Y, Z values, potentiometer value, and button state to Serial
*/

#define BUTTON_PIN 2

int xyzPins[] = {39, 32, 33};   //x, y, z(switch) pins
int potPin = 37;
void setup() {
  Serial.begin(9600);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(xyzPins[2], INPUT_PULLUP);  // pullup resistor for switch
}
void loop() {
  int xVal = analogRead(xyzPins[0]);
  int yVal = analogRead(xyzPins[1]);
  int zVal = digitalRead(xyzPins[2]);
  int potVal = analogRead(potPin);
  int buttonState = digitalRead(BUTTON_PIN);
  Serial.printf("%d,%d,%d,%d,%d\n",
              xVal, yVal, zVal, potVal, buttonState);
  delay(100);
}
