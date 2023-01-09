#define joystickX A1
#define joystickY A0 

int button =  2; 

const int PAUSE = 10; 
long lastAction = -1; 

void setup() {
  Serial.begin(9600); 
}

void loop() {

  long currentTimestamp = millis(); 

  if(lastAction < (currentTimestamp-PAUSE)){
    lastAction = currentTimestamp; 

    int x = analogRead(joystickX);
    int y = analogRead(joystickY);
   
    float x_conv = x / 4.011764705882353;
    float y_conv = y / 4.011764705882353;
    
    byte xyxoords[]  = {round(x_conv), round(y_conv)};
    Serial.write(xyxoords, sizeof(xyxoords) );

  }
}

