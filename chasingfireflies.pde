import java.util.ArrayList;
import java.util.Collections;
import processing.serial.*;

Serial myPort;
String val;

int analogMax = 4095;

PFont titleFont;
PFont buttonFont;
PFont leaderboardFont13;
PFont leaderboardFont14;
PFont leaderboardFont15;
PFont leaderboardFont16;

boolean gameStarted = false;
boolean gameOver = false;

int numFireflies = 35;
Firefly[] fireflies = new Firefly[numFireflies];

// Serial input variables
int joystickX = 2048;
int joystickY = 2048;
int joystickZ = 1;
int potValue = 0;
int catchButton = 1;

int previousCatchButton = 1;
boolean buttonJustPressed = false;

int previousJoystickButton = 1;
boolean joystickButtonJustPressed = false;

// Score-screen joystick navigation
int selectedScoreOption = 0;
// 0 = PLAY AGAIN
// 1 = RETURN HOME

int previousJoystickZ = 1;
boolean scoreMenuDirectionReady = true;

// Gameplay variables
Firefly targetFirefly;
float jarY = 300;
float jarX = 160;
float jarScale = 1.0;
float minJarScale = 1.0;
float maxJarScale = 2.0;
int roundNumber = 1;
float fireflySpeedMultiplier = 1.0;
float speedIncreasePerRound = 1.30;
int gameDuration = 45; // Game lasts 45 seconds
int catchTime = gameDuration;
int gameStartTime;
int timeRemaining;
int score = 0;
int pointsForSmallJar = 100;
float targetJarX;
float targetJarY;
float joystickSmoothness = 0.15;

// Species discovery indicator
boolean[] speciesIndicatorShown = new boolean[4];

boolean showSpeciesIndicator = false;
int speciesIndicatorStartTime = 0;
int speciesIndicatorDuration = 2400;

int currentIndicatorTier = 0;

ArrayList<JarGlow> jarGlows = new ArrayList<JarGlow>();

// --------------------------------------------------
// END SEQUENCE AND RELEASE ANIMATION
// --------------------------------------------------

ArrayList<Integer> caughtFireflyColors = new ArrayList<Integer>();
ArrayList<ReleaseFirefly> releasedFireflies =
  new ArrayList<ReleaseFirefly>();

int endPhase = 0;
// 0 = firefly got away screen
// 1 = release animation
// 2 = final score screen

int gameOverStartTime;
int releaseStartTime;

int gotAwayDuration = 2200;
int releaseDuration = 4500;

int releaseStagger = 250;       // Time between fireflies, in milliseconds
int releaseGlowDuration = 300;  // Glow holds before transforming
int releaseTransformDuration = 450;
int releaseGatherDuration = 550;
int releaseTransitDuration = 450;

float lidOpenAngle = 0;

// --------------------------------------------------
// LEADERBOARD
// --------------------------------------------------

ArrayList<Integer> highScores = new ArrayList<Integer>();

boolean scoreSubmitted = false;
boolean newHighScore = false;
boolean newLeaderboardScore = false;

int newScoreRank = -1; //Rank of this game's score, -1 means no entry

int maxLeaderboardEntries = 10;
String leaderboardFile = "leaderboard.txt";

void setup() {
  size(800, 600);
  printArray(Serial.list());
  String portName = Serial.list()[6];
  println(portName);
  myPort = new Serial(this, portName, 9600);
  smooth(8);

  // Load cursive font; fall back to an italic serif if unavailable
  try {
    titleFont = createFont("CedarvilleCursive-Regular.ttf", 58);
  } catch (Exception e) {
    titleFont = createFont("Serif Italic", 58);
  }
  
  try {
    buttonFont = createFont("Unkempt-Regular.ttf", 24);
  } catch (Exception e) {
    buttonFont = createFont("Serif Italic", 24);
  }
  
  try {
    leaderboardFont13 = createFont("LoveYaLikeASister-Regular.ttf", 13);
  } catch (Exception e) {
    leaderboardFont13 = createFont("Serif Italic", 13);
  }
  
  try {
    leaderboardFont14 = createFont("LoveYaLikeASister-Regular.ttf", 14);
  } catch (Exception e) {
    leaderboardFont14 = createFont("Serif Italic", 14);
  }
  
  try {
    leaderboardFont15 = createFont("LoveYaLikeASister-Regular.ttf", 15);
  } catch (Exception e) {
    leaderboardFont15 = createFont("Serif Italic", 15);
  }
  
  try {
    leaderboardFont16 = createFont("LoveYaLikeASister-Regular.ttf", 16);
  } catch (Exception e) {
    leaderboardFont16 = createFont("Serif Italic", 16);
  }

  // Create background fireflies for the home screen
  for (int i = 0; i < numFireflies; i++) {
    fireflies[i] = new Firefly();
  }

  // Create the first gameplay firefly
  targetFirefly = new Firefly();
  
  loadLeaderboard();
}

void serialInput() {
  while (myPort.available() > 0){
    String val = myPort.readStringUntil('\n');

    if (val == null){
      break;
    }
    
    val = trim(val);
    
    int[] xyzpb = int(split(val, ','));
    
  
    if (xyzpb.length == 5){
        int x = xyzpb[0];
        int y = xyzpb[1];
        int z = xyzpb[2];
        int p = xyzpb[3];
        int b = xyzpb[4];
        
        joystickX = x;
        joystickY = y;
        joystickZ = z;
        potValue = p;
        catchButton = b;
        
        //println("joystick Z: " + joystickZ);
    }
  }
}

void draw() {
  serialInput();
  
  buttonJustPressed = previousCatchButton == 1 && catchButton == 0;
  previousCatchButton = catchButton;
  
  // Detect a fresh press of the joystick button.
  joystickButtonJustPressed = (previousJoystickZ != 0 && joystickZ == 0);
  previousJoystickButton = joystickZ;
  
  
  if (!gameStarted) {
    drawOpeningScreen();
    if(buttonJustPressed||joystickButtonJustPressed){
      restartGame();
    }
  } else if (gameOver) {
    if (endPhase == 0) {
      drawGameOverScreen();

      // Give the "firefly got away" message time to appear
      if (millis() - gameOverStartTime >= gotAwayDuration) {
        startReleaseAnimation();
      }

    } else if (endPhase == 1) {
      drawReleaseAnimation();

    } else if (endPhase == 2) {
      processScoreMenuInput();
      drawFinalScoreScreen();
    }

  } else {
    drawGameScreen();
  }
}


// --------------------------------------------------
// HOME SCREEN
// --------------------------------------------------

void drawOpeningScreen() {
  background(8, 24, 33);

  // Subtle green atmospheric glow
  noStroke();
  for (int i = 5; i >= 0; i--) {
    fill(30, 75, 60, 10);
    ellipse(
      width / 2,
      height / 2 + 30,
      250 + i * 90,
      250 + i * 90
    );
  }

  // Floating, glowing background fireflies
  for (Firefly f : fireflies) {
    f.update();
    f.display();
  }

  // Cursive title
  textFont(titleFont);
  textAlign(CENTER, CENTER);
  textSize(58);
  fill(255, 240, 185);
  text("Chasing Fireflies", width / 2, height / 2 - 65);

  // Play button
  drawPlayButton(
    width / 2,
    height / 2 + 75,
    180,
    58
  );
}


void drawPlayButton(float x, float y, float w, float h) {
  noStroke();

  // Soft glow around the selected PLAY button.
  fill(220, 245, 150, 25);

  // Simple ring to show that PLAY is selected.
  rectMode(CENTER);
  rect(x, y, w + 18, h + 18, 23);
  noFill();
  stroke(220, 245, 150);
  strokeWeight(2);
  rect(x, y, w + 18, h + 18, 23);

  // PLAY button background.
  noStroke();
  fill(180, 205, 125);
  rect(x, y, w, h, 18);

  // PLAY text.
  fill(20, 43, 39);
  textFont(buttonFont);
  textAlign(CENTER, CENTER);
  textSize(21);
  text("PLAY", x, y);

  // Restore drawing settings.
  rectMode(CORNER);
  noStroke();
}

// --------------------------------------------------
// GAMEPLAY SCREEN
// --------------------------------------------------

void drawGameScreen() {
  timeRemaining = gameDuration - (millis() - gameStartTime) / 1000;

  // Read the potentiometer and map it to the jar size.
  jarScale = map(
    potValue,
    0,
    analogMax,
    minJarScale,
    maxJarScale
  );

  jarScale = constrain(
    jarScale,
    minJarScale,
    maxJarScale
  );
  
  //// Map the potentiometer to joystick sensitivity.
  //joystickSmoothness = map(potValue, 0, 4095, 0.04, 0.4);
  
  //// Keep the value within a safe range.
  //joystickSmoothness = constrain(joystickSmoothness, 0.04, 0.4);

  //// Map joystick input to the jar's target position.
  //targetJarX = map(
  //  joystickX,
  //  0,
  //  analogMax,
  //  31 * jarScale,
  //  width - 31 * jarScale
  //);
  
  //targetJarY = map(
  //  joystickY,
  //  0,
  //  analogMax,
  //  57 * jarScale,
  //  height - 43 * jarScale
  //);
  
  //// Keep the target inside the screen.
  //targetJarX = constrain(
  //  targetJarX,
  //  31 * jarScale,
  //  width - 31 * jarScale
  //);
  
  //targetJarY = constrain(
  //  targetJarY,
  //  57 * jarScale,
  //  height - 43 * jarScale
  //);
  
  //// Gradually move the jar toward the target.
  //jarX = lerp(jarX, targetJarX, joystickSmoothness);
  //jarY = lerp(jarY, targetJarY, joystickSmoothness);
  
  // Adjust these values if your joystick's center is different.
  float joystickCenterX = 2048;
  float joystickCenterY = 2048;
  
  // Ignore small fluctuations when the joystick is released.
  float deadzone = 180;
  
  // Maximum jar movement speed in pixels per frame.
  float moveSpeed = map(potValue, 0, 4095, 4, 24);
  
  // Calculate how far the joystick is from its center.
  float dx = joystickX - joystickCenterX;
  float dy = joystickY - joystickCenterY;
  
  // Only move when the joystick is pushed outside the deadzone.
  if (abs(dx) > deadzone) {
    jarX += map(
      dx,
      -2048, 2048,
      -moveSpeed, moveSpeed
    );
  }
  
  if (abs(dy) > deadzone) {
    jarY += map(
      dy,
      -2048, 2048,
      -moveSpeed, moveSpeed
    );
  }
  
  // Keep the jar inside the screen.
  jarX = constrain(
    jarX,
    31 * jarScale,
    width - 31 * jarScale
  );
  
  jarY = constrain(
    jarY,
    57 * jarScale,
    height - 43 * jarScale
  );
    
  if (catchButton == 0 && catchTime-timeRemaining>1) {
    println("entered");
    attemptCatch();
    catchTime = timeRemaining;
    println("catch time: " + catchTime);
  }

  if (timeRemaining <= 0) {
    timeRemaining = 0;
    startGameOver();
    return;
  }

  background(8, 24, 33);

  // Soft atmospheric glow
  noStroke();
  for (int i = 5; i >= 0; i--) {
    fill(30, 75, 60, 8);
    ellipse(
      width / 2,
      height / 2,
      200 + i * 100,
      200 + i * 100
    );
  }

  // Round counter
  textAlign(LEFT, TOP);
  textSize(22);
  fill(255, 240, 185);
  text("Round " + roundNumber, 30, 25);

  //textAlign(LEFT, TOP);
  //textSize(16);
  //fill(190, 210, 190);
  //text(
  //  "Firefly speed: " + nf(fireflySpeedMultiplier, 1, 2) + "x",
  //  30,
  //  55
  //);
  
  textAlign(RIGHT, TOP);
  textSize(22);
  
  if (timeRemaining <= 10) {
    fill(255, 110, 100); // Red when time is almost up
  } else {
    fill(255, 240, 185);
  }
  
  text("Time: " + timeRemaining + "s", width - 30, 25);

  // Current score multiplier based on jar size
  float scoreMultiplier = 1.0 / jarScale;
  
  textAlign(LEFT, TOP);
  textSize(18);
  fill(255, 240, 185);
  text("Score: " + score, 30, 80);
  
  // Display the current multiplier
  textSize(18);
  fill(220, 245, 150);
  text(
    "Score Multiplier: " + nf(scoreMultiplier, 1, 2) + "x",
    30,
    108
  );

  // Instructions
  textAlign(CENTER, TOP);
  textSize(15);
  fill(190, 210, 190);
  text(
    "Move jar with joystick • Press button to catch • Turn Dial to Change Jar Size & Speed",
    width / 2,
    30
  );

  // Move and draw the target firefly
  targetFirefly.update();
  targetFirefly.display();

  // Draw the captured fireflies inside the jar.
  for (JarGlow glow : jarGlows) {
    glow.update();
    glow.display(jarX, jarY, jarScale);
  }
  
  // Open when the target firefly is in range;
  // close when it leaves the existing catch radius.
  float targetLidAngle = isTargetInCatchRange() ? 1.15 : 0;
  
  lidOpenAngle = lerp(lidOpenAngle, targetLidAngle, 0.18);

  // Draw the jar after the firefly so it appears in front
  drawJar(jarX, jarY);

  //updateSpeciesIndicator();
  //drawSpeciesIndicator();
  drawFireflyGuide();
}

void updateSpeciesIndicator() {
  if (targetFirefly == null) return;

  int tier = round(targetFirefly.pointMultiplier);

  // Only show the indicator once per species per run.
  if (tier < 1 || tier > 3) return;

  if (!speciesIndicatorShown[tier]) {
    speciesIndicatorShown[tier] = true;
    currentIndicatorTier = tier;
    speciesIndicatorStartTime = millis();
    showSpeciesIndicator = true;
  }
}


void drawSpeciesIndicator() {
  if (!showSpeciesIndicator) return;

  int elapsed = millis() - speciesIndicatorStartTime;

  if (elapsed >= speciesIndicatorDuration) {
    showSpeciesIndicator = false;
    return;
  }

  // Fade in and fade out smoothly.
  float alpha = 255;

  if (elapsed < 300) {
    alpha = map(elapsed, 0, 300, 0, 255);
  } else if (elapsed > speciesIndicatorDuration - 500) {
    alpha = map(
      elapsed,
      speciesIndicatorDuration - 500,
      speciesIndicatorDuration,
      255,
      0
    );
  }

  String speciesName;
  String scientificName;
  String rarity;
  String multiplier;

  int speciesColor;

  if (currentIndicatorTier == 1) {
    speciesName = "Big Dipper Firefly";
    scientificName = "Photinus pyralis";
    rarity = "COMMON";
    multiplier = "x1 POINTS";
    speciesColor = color(220, 245, 75);

  } else if (currentIndicatorTier == 2) {
    speciesName = "Multicolored Firefly";
    scientificName = "Photuris versicolor";
    rarity = "UNCOMMON";
    multiplier = "x2 POINTS";
    speciesColor = color(70, 255, 100);

  } else {
    speciesName = "Blue Ghost Firefly";
    scientificName = "Phausis reticulata";
    rarity = "RARE";
    multiplier = "x3 POINTS";
    speciesColor = color(100, 190, 255);
  }

  float cardWidth = 320;
  float cardHeight = 104;
  float cardX = width / 2 - cardWidth / 2;
  float cardY = 145;

  pushStyle();

  // Dark translucent card.
  rectMode(CORNER);
  noStroke();
  fill(8, 24, 33, alpha * 0.92);
  rect(cardX, cardY, cardWidth, cardHeight, 12);

  // Glowing rarity-colored border.
  noFill();
  stroke(
    red(speciesColor),
    green(speciesColor),
    blue(speciesColor),
    alpha
  );
  strokeWeight(1.5);
  rect(cardX, cardY, cardWidth, cardHeight, 12);

  textAlign(CENTER, CENTER);
  textFont(buttonFont);

  // Discovery heading.
  fill(220, 235, 210, alpha);
  textSize(12);
  text("✦  NEW SPECIES DISCOVERED  ✦",
       width / 2, cardY + 17);

  // Species name.
  fill(255, 240, 205, alpha);
  textSize(20);
  text(speciesName, width / 2, cardY + 42);

  // Scientific name.
  fill(195, 215, 195, alpha);
  textSize(12);
  text(scientificName, width / 2, cardY + 62);

  // Rarity and multiplier.
  fill(
    red(speciesColor),
    green(speciesColor),
    blue(speciesColor),
    alpha
  );
  textSize(14);
  text(rarity + "   •   " + multiplier,
       width / 2, cardY + 84);

  popStyle();
}

void resetSpeciesIndicators() {
  for (int i = 0; i < speciesIndicatorShown.length; i++) {
    speciesIndicatorShown[i] = false;
  }

  showSpeciesIndicator = false;
  currentIndicatorTier = 0;
  speciesIndicatorStartTime = 0;
}


void drawFireflyGuide() {
  float guideX = width - 165;
  float guideY = 80;
  float guideW = 140;
  float guideH = 112;

  pushStyle();

  // Subtle translucent background
  rectMode(CORNER);
  noStroke();
  fill(8, 24, 33, 190);
  rect(guideX, guideY, guideW, guideH, 10);

  // Soft border
  noFill();
  stroke(65, 95, 79, 150);
  strokeWeight(1);
  rect(guideX, guideY, guideW, guideH, 10);

  textFont(buttonFont);
  textAlign(LEFT, CENTER);

  // Heading
  fill(195, 215, 195, 220);
  textSize(13);
  text("FIREFLY GUIDE", guideX + 12, guideY + 15);

  // Common: yellow-green
  drawGuideRow(
    guideX + 12, guideY + 39,
    color(220, 245, 75),
    "Common", "x1"
  );

  // Uncommon: bright green
  drawGuideRow(
    guideX + 12, guideY + 63,
    color(70, 255, 100),
    "Uncommon", "x2"
  );

  // Rare: blue
  drawGuideRow(
    guideX + 12, guideY + 87,
    color(100, 190, 255),
    "Rare", "x3"
  );

  popStyle();
}


void drawGuideRow(
  float x,
  float y,
  int dotColor,
  String rarity,
  String multiplier
) {
  pushStyle();

  // Small glowing dot
  noStroke();
  fill(
    red(dotColor),
    green(dotColor),
    blue(dotColor),
    45
  );
  ellipse(x + 5, y, 16, 16);

  fill(dotColor);
  ellipse(x + 5, y, 7, 7);

  // Rarity label
  textAlign(LEFT, CENTER);
  textFont(buttonFont);
  textSize(13);
  fill(225, 235, 215);
  text(rarity, x + 18, y);

  // Points multiplier
  textAlign(RIGHT, CENTER);
  fill(dotColor);
  text(multiplier, x + 119, y);

  popStyle();
}


// --------------------------------------------------
// JAR
// --------------------------------------------------


void drawJar(float x, float y) {
  pushMatrix();
  translate(x, y);
  scale(jarScale);

  rectMode(CENTER);
  ellipseMode(CENTER);

  color glassFill = color(145, 205, 190, 38);
  color glassEdge = color(180, 225, 210, 190);
  color glassHighlight = color(235, 255, 240, 155);

  // Glass body
  stroke(glassEdge);
  strokeWeight(2);
  fill(glassFill);

  beginShape();
  vertex(-31, -31);
  bezierVertex(-31, -39, -23, -43, -19, -44);
  vertex(-15, -47);
  vertex(-15, -51);
  vertex(15, -51);
  vertex(15, -47);
  vertex(19, -44);
  bezierVertex(25, -41, 31, -37, 31, -29);
  vertex(31, 31);
  bezierVertex(31, 39, 25, 43, 17, 43);
  vertex(-17, 43);
  bezierVertex(-25, 43, -31, 39, -31, 31);
  endShape(CLOSE);

  // Subtle tint inside the glass
  noStroke();
  fill(125, 195, 175, 22);
  rect(0, 0, 53, 65, 8);

  // Crisp glass outline
  noFill();
  stroke(glassEdge);
  strokeWeight(2);

  beginShape();
  vertex(-31, -31);
  bezierVertex(-31, -39, -23, -43, -19, -44);
  vertex(-15, -47);
  vertex(-15, -51);
  vertex(15, -51);
  vertex(15, -47);
  vertex(19, -44);
  bezierVertex(25, -41, 31, -37, 31, -29);
  vertex(31, 31);
  bezierVertex(31, 39, 25, 43, 17, 43);
  vertex(-17, 43);
  bezierVertex(-25, 43, -31, 39, -31, 31);
  endShape(CLOSE);

  // Glass reflections
  stroke(glassHighlight);
  strokeWeight(3);
  line(-23, -29, -23, 23);

  stroke(235, 255, 240, 90);
  strokeWeight(2);
  line(-17, -37, -12, -40);

  noFill();
  stroke(235, 255, 240, 100);
  strokeWeight(2);
  bezier(-25, -32, -24, -38, -19, -40, -16, -41);

  // Thick glass bottom
  stroke(glassEdge);
  strokeWeight(2);
  noFill();
  arc(0, 31, 48, 12, 0, PI);

  stroke(220, 250, 235, 100);
  arc(0, 31, 39, 6, 0, PI);

  // Jar neck and rim
  stroke(195, 230, 210, 210);
  strokeWeight(1.5);
  fill(155, 195, 175, 150);
  rect(0, -51, 35, 13, 6);

  // Dark opening
  noStroke();
  fill(20, 45, 40, 210);
  ellipse(0, -54, 25, 7);

  // Front rim reflection
  noFill();
  stroke(235, 255, 240, 170);
  strokeWeight(1.5);
  arc(0, -51, 29, 8, 0, PI);

  // Draw the lid last so it covers the opening when closed.
  drawJarLid();

  popMatrix();

  rectMode(CORNER);
  ellipseMode(CENTER);
  noStroke();
}


void drawJarLid() {
  pushMatrix();

  // Fixed hinge at the right edge of the jar mouth.
  translate(17, -56);

  // Positive rotation swings the left end upward.
  rotate(lidOpenAngle);

  // Main lid
  stroke(180, 220, 200, 230);
  strokeWeight(1.5);
  fill(100, 145, 120, 245);
  rect(-17.5, 2, 36, 8, 4);

  // Soft highlight on the lid
  stroke(220, 245, 220, 210);
  strokeWeight(1.5);
  line(-31, 0, -5, 0);

  popMatrix();

  // Fixed hinge pin
  pushStyle();
  stroke(210, 235, 210, 230);
  strokeWeight(2);
  point(17, -56);
  popStyle();
}


// --------------------------------------------------
// CATCH MECHANIC
// --------------------------------------------------

void attemptCatch() {
  if (isTargetInCatchRange()) {
    // Award points only when the firefly is inside the jar.
    int pointsEarned = round(
      (pointsForSmallJar / jarScale) * targetFirefly.pointMultiplier
    );

    score += pointsEarned;

    // Add the caught firefly to the jar.
    caughtFireflyColors.add((int) targetFirefly.fireflyColor);
    jarGlows.add(new JarGlow(targetFirefly.fireflyColor));

    // Advance to the next round.
    roundNumber++;
    fireflySpeedMultiplier *= speedIncreasePerRound;
    targetFirefly = new Firefly(fireflySpeedMultiplier);

  } else {
    // The firefly escaped: no points are awarded.
    startGameOver();
  }
}

boolean isTargetInCatchRange() {
  if (targetFirefly == null) {
    return false;
  }

  float localX = (targetFirefly.x - jarX) / jarScale;
  float localY = (targetFirefly.y - jarY) / jarScale;

  return localX >= -17 && localX <= 17
      && localY >= -51 && localY <= 43;
}

// --------------------------------------------------
// GAME OVER SCREEN
// --------------------------------------------------

void drawGameOverScreen() {
  background(8, 24, 33);

  // Soft green glow
  noStroke();
  for (int i = 5; i >= 0; i--) {
    fill(30, 75, 60, 10);
    ellipse(
      width / 2,
      height / 2,
      200 + i * 85,
      200 + i * 85
    );
  }

  // The firefly got away
  textFont(titleFont);
  textAlign(CENTER, CENTER);
  textSize(54);
  fill(255, 240, 185);
  text(
    "The firefly got away...",
    width / 2,
    height / 2 - 20
  );
}


void drawFinalScoreScreen() {
  background(8, 24, 33);

  // Soft green atmospheric glow
  noStroke();
  for (int i = 5; i >= 0; i--) {
    fill(30, 75, 60, 10);
    ellipse(
      width / 2,
      height / 2,
      200 + i * 85,
      200 + i * 85
    );
  }

  // Heading
  textFont(titleFont);
  textAlign(CENTER, CENTER);
  textSize(42);
  fill(255, 240, 185);

  if (newHighScore){
    text("New High Score!", width / 2, 43);
  } else if (newLeaderboardScore) {
    text("You Made the Leaderboard!", width / 2, 43);
  } else {
    text("Final Score", width / 2, 43);
  }

  // Final score and round reached
  textFont(leaderboardFont16);
  fill(195, 215, 195);

  text(
    "You reached Round " + roundNumber,
    width / 2,
    83
  );

  textSize(22);
  fill(220, 245, 150);

  text(
    "Your Score: " + score,
    width / 2,
    111
  );

  // Leaderboard heading
  textSize(19);
  fill(255, 240, 185);

  text("TOP TEN FIREFLY CATCHERS", width / 2, 150);

  // Decorative divider
  stroke(100, 145, 110, 150);
  strokeWeight(1);
  line(240, 168, 560, 168);
  noStroke();

  // Leaderboard column headings
  textFont(leaderboardFont13);
  fill(160, 185, 170);

  textAlign(LEFT, CENTER);
  text("RANK", 260, 185);

  textAlign(RIGHT, CENTER);
  text("SCORE", 540, 185);

  // Draw the top ten scores
  for (int i = 0; i < maxLeaderboardEntries; i++) {
    float rowY = 210 + i * 23;

    if (i < highScores.size()) {
      int savedScore = highScores.get(i);

      // Highlight only this game's newly added leaderboard entry
      if (i == newScoreRank) {
        fill(220, 245, 150);
      } else if (i == 0) {
        fill(255, 240, 185);
      } else {
        fill(195, 215, 195);
      }

      textFont(leaderboardFont15);

      textAlign(LEFT, CENTER);
      text(nf(i + 1, 2) + ".", 260, rowY);

      textAlign(RIGHT, CENTER);
      text(str(savedScore), 540, rowY);

    } else {
      // Empty leaderboard slots
      fill(100, 125, 115);
      textFont(leaderboardFont14);

      textAlign(LEFT, CENTER);
      text(nf(i + 1, 2) + ".", 260, rowY);

      textAlign(RIGHT, CENTER);
      text("---", 540, rowY);
    }
  }

  // Buttons
  drawRestartButton(
    width / 2,
    480,
    180,
    45
  );

  drawHomeButton(
    width / 2,
    540,
    180,
    42
  );
}


void startGameOver() {
  if (!gameOver) {
    gameOver = true;
    endPhase = 0;
    gameOverStartTime = millis();
  }
}


void drawRestartButton(float x, float y, float w, float h) {
  pushStyle();

  // Same soft green selection treatment as the PLAY button.
  if (selectedScoreOption == 0) {
    noStroke();
    fill(220, 245, 150, 25);
    rectMode(CENTER);
    rect(x, y, w + 18, h + 18, 23);

    noFill();
    stroke(220, 245, 150);
    strokeWeight(2);
    rect(x, y, w + 18, h + 18, 23);
  }

  noStroke();
  fill(180, 205, 125);
  rectMode(CENTER);
  rect(x, y, w, h, 16);

  fill(20, 43, 39);
  textFont(buttonFont);
  textAlign(CENTER, CENTER);
  textSize(19);
  text("PLAY AGAIN", x, y);

  popStyle();
}


void drawHomeButton(float x, float y, float w, float h) {
  pushStyle();

  // The ring follows RETURN HOME when that option is selected.
  if (selectedScoreOption == 1) {
    noStroke();
    fill(220, 245, 150, 25);
    rectMode(CENTER);
    rect(x, y, w + 18, h + 18, 23);

    noFill();
    stroke(220, 245, 150);
    strokeWeight(2);
    rect(x, y, w + 18, h + 18, 23);
  }

  noStroke();
  fill(180, 205, 125);
  rectMode(CENTER);
  rect(x, y, w, h, 16);

  fill(20, 43, 39);
  textFont(buttonFont);
  textAlign(CENTER, CENTER);
  textSize(19);
  text("RETURN HOME", x, y);

  popStyle();
}

void restartGame() {
  gameOver = false;
  gameStarted = true;

  score = 0;
  roundNumber = 1;
  jarY = height / 2;
  fireflySpeedMultiplier = 1.0;

  gameStartTime = millis();
  targetFirefly = new Firefly(fireflySpeedMultiplier);
  
  scoreSubmitted = false;
  newHighScore = false;
  newLeaderboardScore = false;
  newScoreRank = -1;
  caughtFireflyColors.clear();
  releasedFireflies.clear();
  endPhase = 0;
  jarX = width / 2;
  jarScale = minJarScale;
  resetSpeciesIndicators();
  jarGlows.clear();
  lidOpenAngle = 0;
  catchTime = gameDuration;
}

void startReleaseAnimation() {
  // Nothing to release? Skip straight to the score screen.
  if (jarGlows.isEmpty()) {
    submitFinalScore();
    endPhase = 2;
    return;
  }
  
  endPhase = 1;
  releaseStartTime = millis();

  jarX = width / 2;
  jarY = height / 2;

  lidOpenAngle = 0;
  releasedFireflies.clear();

  for (int i = 0; i < jarGlows.size(); i++) {
    JarGlow glow = jarGlows.get(i);
    releasedFireflies.add(
      new ReleaseFirefly(glow, i * releaseStagger, releaseStartTime)
    );
  }
}

void drawReleaseAnimation() {
  background(8, 24, 33);

  // Animate the lid opening over 800 milliseconds.
  float lidProgress = constrain(
    (millis() - releaseStartTime) / 800.0,
    0,
    1
  );

  // Smooth ease-out rotation.
  lidOpenAngle =
    1.15 * (1 - pow(1 - lidProgress, 3));

  // Atmospheric glow
  noStroke();
  for (int i = 5; i >= 0; i--) {
    fill(30, 75, 60, 10);
    ellipse(
      width / 2,
      height / 2,
      200 + i * 85,
      200 + i * 85
    );
  }

  // Release title
  textFont(titleFont);
  textAlign(CENTER, CENTER);
  textSize(42);
  fill(255, 240, 185);
  text("Time to let them go...", width / 2, 90);

  // Each firefly controls its own glow and escape path.
  for (ReleaseFirefly f : releasedFireflies) {
    f.update();
    f.display();
  }

  // Draw jar and animated lid in front.
  drawJar(jarX, jarY);

  // Wait for the last firefly to travel through the opening
  // and have time to drift offscreen.
  int lastDelay = max(
    0,
    (releasedFireflies.size() - 1) * releaseStagger
  );

  int totalReleaseDuration = max(
    releaseDuration,
    lastDelay
      + releaseGlowDuration
      + releaseTransformDuration
      + releaseGatherDuration
      + releaseTransitDuration
      + 3500
  );

  if (millis() - releaseStartTime >= totalReleaseDuration) {
    submitFinalScore();
    endPhase = 2;
  }
}

void loadLeaderboard() {
  highScores.clear();

  String[] savedScores = loadStrings(leaderboardFile);

  if (savedScores == null) {
    return; // No leaderboard exists yet
  }

  for (String savedScore : savedScores) {
    String cleaned = trim(savedScore);

    if (cleaned.length() > 0) {
      try {
        int value = Integer.parseInt(cleaned);

        if (value >= 0) {
          highScores.add(value);
        }
      } catch (NumberFormatException e) {
        // Ignore invalid lines in the score file
      }
    }
  }

  // Sort highest to lowest
  Collections.sort(highScores, Collections.reverseOrder());

  // Keep only the top ten
  while (highScores.size() > maxLeaderboardEntries) {
    highScores.remove(highScores.size() - 1);
  }
}


void submitFinalScore() {
  // Prevent this game's score from being submitted more than once
  if (scoreSubmitted) {
    return;
  }

  scoreSubmitted = true;

  // ----------------------------------------------
  // 1. Check whether this is a new all-time high
  // ----------------------------------------------

  int highestEverScore = 0;

  if (highScores.size() > 0) {
    highestEverScore = highScores.get(0);
  }

  newHighScore = score > highestEverScore;

  // ----------------------------------------------
  // 2. Check whether this score makes the top ten
  // ----------------------------------------------

  newLeaderboardScore =
    highScores.size() < maxLeaderboardEntries ||
    (highScores.size() > 0 &&
     score > highScores.get(highScores.size() - 1));

  // ----------------------------------------------
  // 3. Determine the score's rank before inserting
  // ----------------------------------------------

  newScoreRank = -1;

  int insertionIndex = 0;

  // Place the new score after any existing tied scores
  while (insertionIndex < highScores.size() &&
         highScores.get(insertionIndex) >= score) {
    insertionIndex++;
  }

  if (newLeaderboardScore) {
    newScoreRank = insertionIndex;
  }

  // ----------------------------------------------
  // 4. Add the score and sort highest to lowest
  // ----------------------------------------------

  highScores.add(score);

  Collections.sort(
    highScores,
    Collections.reverseOrder()
  );

  // ----------------------------------------------
  // 5. Keep only the top ten
  // ----------------------------------------------

  while (highScores.size() > maxLeaderboardEntries) {
    highScores.remove(highScores.size() - 1);
  }

  // ----------------------------------------------
  // 6. Save the leaderboard to this computer
  // ----------------------------------------------

  String[] savedScores = new String[highScores.size()];

  for (int i = 0; i < highScores.size(); i++) {
    savedScores[i] = str(highScores.get(i));
  }

  saveStrings(leaderboardFile, savedScores);
}


// --------------------------------------------------
// INPUT
// --------------------------------------------------

void keyPressed() {
  if (gameOver && endPhase == 2) {
    if (key == 'r' || key == 'R') {
      restartGame();
    }
    return;
  }

  if (!gameStarted) {
    return;
  }
  
  //// Grow the jar with 0
  //if (key == '0') {
  //  jarScale = min(jarScale + 0.1, maxJarScale);
  //}

  //// Shrink the jar with 9, down to its original size
  //if (key == '9') {
  //  jarScale = max(jarScale - 0.1, minJarScale);
  //}

  //// Move jar in all four directions
  //if (key == CODED) {
  //  if (keyCode == UP) {
  //    jarY -= 22;
  //  } else if (keyCode == DOWN) {
  //    jarY += 22;
  //  } else if (keyCode == LEFT) {
  //    jarX -= 22;
  //  } else if (keyCode == RIGHT) {
  //    jarX += 22;
  //  }
  
    // Keep jar within screen and Allow the jar to reach every edge and corner
    //jarX = constrain(
    //  jarX,
    //  31 * jarScale,
    //  width - 31 * jarScale
    //);
    
    //jarY = constrain(
    //  jarY,
    //  57 * jarScale,
    //  height - 43 * jarScale
    //);
  //}

//  // Spacebar attempts to catch the firefly
//  if (key == ' ') {
//    attemptCatch();
//  }
}

void mousePressed() {
  if (!gameStarted) {
    float x = width / 2;
    float y = height / 2 + 75;
    float w = 180;
    float h = 58;

    if (mouseX > x - w / 2 &&
        mouseX < x + w / 2 &&
        mouseY > y - h / 2 &&
        mouseY < y + h / 2) {
      gameStarted = true;
      gameOver = false;

      score = 0;
      roundNumber = 1;
      jarY = height / 2;
      fireflySpeedMultiplier = 1.0;
 
      scoreSubmitted = false;
      newHighScore = false;
      newLeaderboardScore = false;
      newScoreRank = -1;
      
      caughtFireflyColors.clear();
      releasedFireflies.clear();
      endPhase = 0;
      gameStartTime = millis();
      targetFirefly = new Firefly(fireflySpeedMultiplier);
    }
  } else if (gameOver && endPhase == 2) {

    // Play Again button
    float playX = width / 2;
    float playY = 480;

    if (mouseX > playX - 90 &&
        mouseX < playX + 90 &&
        mouseY > playY - 22.5 &&
        mouseY < playY + 22.5) {
      restartGame();
      return;
    }

    // Return Home button
    float homeX = width / 2;
    float homeY = 540;

    if (mouseX > homeX - 90 &&
        mouseX < homeX + 90 &&
        mouseY > homeY - 21 &&
        mouseY < homeY + 21) {

      gameStarted = false;
      gameOver = false;
      endPhase = 0;

      score = 0;
      roundNumber = 1;
      jarX = 160;
      jarY = 300;
      //jarX = width/2;
      jarScale = minJarScale;
      fireflySpeedMultiplier = 1.0;

      caughtFireflyColors.clear();
      releasedFireflies.clear();

      scoreSubmitted = false;
      newHighScore = false;
      newLeaderboardScore = false;
      newScoreRank = -1;

      targetFirefly = new Firefly();
      resetSpeciesIndicators();
      jarGlows.clear();
      lidOpenAngle = 0;
      catchTime = gameDuration;
    }
  }

}

void processScoreMenuInput() {
  // Joystick Y: up selects PLAY AGAIN; down selects RETURN HOME.
  if (scoreMenuDirectionReady) {
    if (joystickY < 1200) {
      selectedScoreOption = 0;
      scoreMenuDirectionReady = false;
    } else if (joystickY > 2900) {
      selectedScoreOption = 1;
      scoreMenuDirectionReady = false;
    }
  }

  // Require the joystick to return to center before
  // another navigation movement is registered.
  if (joystickY > 1700 && joystickY < 2400) {
    scoreMenuDirectionReady = true;
  }
  
  if (buttonJustPressed||joystickButtonJustPressed) {
    if (selectedScoreOption == 0) {
      restartGame();
    } else if (selectedScoreOption == 1) {
      returnHome();
    }
  }

  // Remember the current button state for the next frame.
  previousJoystickZ = joystickZ;
}

void returnHome() {
  selectedScoreOption = 0;
  scoreMenuDirectionReady = true;

  gameStarted = false;
  gameOver = false;
  endPhase = 0;

  score = 0;
  roundNumber = 1;
  jarX = 160;
  jarY = 300;
  //jarX = width/2;
  jarScale = minJarScale;
  fireflySpeedMultiplier = 1.0;

  caughtFireflyColors.clear();
  releasedFireflies.clear();

  scoreSubmitted = false;
  newHighScore = false;
  newLeaderboardScore = false;
  newScoreRank = -1;
      
  targetFirefly = new Firefly();
  resetSpeciesIndicators();
  jarGlows.clear();
  lidOpenAngle = 0;
  catchTime = gameDuration;
  
  previousJoystickZ = joystickZ;
  buttonJustPressed = false;
}



// --------------------------------------------------
// FIREFLY
// --------------------------------------------------

class Firefly {
  float x, y;
  float speedX, speedY;
  float phase;
  float pulseSpeed;
  float glowSize;
  float wingPhase;
  float movementMultiplier = 1.0;
  float pointMultiplier;

  color fireflyColor;

  Firefly() {
    this(1.0);  // Normal speed for background fireflies
  }

  Firefly(float speedMultiplier) {
    movementMultiplier = speedMultiplier;
  
    x = random(width);
    y = random(height);
  
    // Randomly choose left or right, with a consistent speed
    float horizontalDirection = random(1) < 0.5 ? -1 : 1;
    speedX = horizontalDirection * random(0.65, 0.85) * movementMultiplier;
    
    // Random vertical direction
    float verticalDirection = random(1) < 0.5 ? -1 : 1;
    speedY = verticalDirection * random(0.12, 0.25) * movementMultiplier;
    
    // Give vertical movement a minimum magnitude
    if (abs(speedY) < 0.12 * movementMultiplier) {
      speedY = (speedY < 0 ? -1 : 1)
             * 0.12 * movementMultiplier;
    }
  
    phase = random(TWO_PI);
    wingPhase = random(TWO_PI);
    pulseSpeed = random(0.025, 0.06);
    glowSize = random(15, 25);
  
    // Choose firefly color and point multiplier based on the round
    if (roundNumber <= 3) {
      // Common: yellow-green
      fireflyColor = color(220, 245, 75);
      pointMultiplier = 1.0;
    } else if (roundNumber <= 6) {
      // Uncommon: bright green
      fireflyColor = color(70, 255, 100);
      pointMultiplier = 2.0;
    } else {
      // Rare: blue
      fireflyColor = color(65, 175, 255);
      pointMultiplier = 3.0;
    }
  }

  void update() {
    x += speedX;
    y += speedY;

    phase += pulseSpeed;
    wingPhase += 0.16;

    // Gentle drifting motion
    x += sin(phase * 0.7) * 0.12 * movementMultiplier;
    y += cos(phase * 0.6) * 0.10 * movementMultiplier;

    // Wrap around screen edges
    if (x < -5) x = width + 5;
    if (x > width + 5) x = -5;
    if (y < -5) y = height + 5;
    if (y > height + 5) y = -5;
  }

  void display() {
    float pulse = (sin(phase) + 1) / 2.0;
    float angle = atan2(speedY, speedX);

    // Abdomen offset in local coordinates
    float abdomenX = -8;
    float abdomenY = 0;

    float glowX = x + abdomenX * cos(angle)
                    - abdomenY * sin(angle);
    float glowY = y + abdomenX * sin(angle)
                    + abdomenY * cos(angle);

    drawGlow(pulse, glowX, glowY);

    pushMatrix();
    translate(x, y);
    rotate(angle);

    drawWings();
    drawBody();
    drawAntennae();

    popMatrix();
  }

  void drawGlow(float pulse, float glowX, float glowY) {
    float r = red(fireflyColor);
    float g = green(fireflyColor);
    float b = blue(fireflyColor);

    noStroke();

    float glowRadius = glowSize * (2.5 + pulse * 0.4);

    for (int i = 20; i >= 1; i--) {
      float t = i / 20.0;
      float diameter = glowRadius * t;
      float alpha = 55 * pow(1 - t, 2.0);

      fill(r, g, b, alpha);
      ellipse(glowX, glowY, diameter, diameter);
    }

    fill(r, g, b, 180 + pulse * 75);
    ellipse(
      glowX, glowY,
      glowSize * 0.7,
      glowSize * 0.7
    );
  }

  void drawWings() {
    color wingColor = color(12, 29, 31);

    noStroke();
    fill(wingColor);

    for (int pair = 0; pair < 3; pair++) {
      float flutter =
        sin(wingPhase + pair * 1.1) * 0.13;

      float wingX = -2 - pair * 3.0;

      pushMatrix();
      translate(wingX, 0);

      // Upper wing
      pushMatrix();
      rotate(-0.55 - flutter);
      ellipse(-2, -5, 10, 16);
      popMatrix();

      // Lower wing
      pushMatrix();
      rotate(0.55 + flutter);
      ellipse(-2, 5, 10, 16);
      popMatrix();

      popMatrix();
    }
  }

  void drawBody() {
    noStroke();

    // Abdomen
    fill(5, 13, 18);
    ellipse(-8, 0, 15, 6);

    // Thorax
    ellipse(0, 0, 9, 7);

    // Head
    ellipse(6, 0, 7, 7);

    // Eyes
    fill(35, 45, 40);
    ellipse(7.5, -1.3, 1.5, 1.5);
    ellipse(7.5, 1.3, 1.5, 1.5);
  }

  void drawAntennae() {
    stroke(5, 13, 18);
    strokeWeight(1.1);
    noFill();

    bezier(
      7, -2,
      9, -5,
      12, -5,
      13, -7
    );

    bezier(
      7, 2,
      9, 5,
      12, 5,
      13, 7
    );

    noStroke();
  }
}



class ReleaseFirefly {
  Firefly insect;
  JarGlow source;

  float x, y;
  float startX, startY;
  float vx, vy;
  float phase, driftPhase;

  int glowColor;
  int delayMs;
  int animationStartTime;

  boolean releaseStarted = false;
  boolean escaping = false;
  boolean finished = false;

  ReleaseFirefly(
    JarGlow source,
    int delay,
    int sharedStartTime
  ) {
    this.source = source;

    glowColor = source.glowColor;
    delayMs = delay;
    animationStartTime = sharedStartTime;

    x = jarX + source.x * jarScale;
    y = jarY + source.y * jarScale;

    startX = x;
    startY = y;

    insect = new Firefly();
    insect.fireflyColor = glowColor;

    // Face upward while inside the jar.
    insect.speedX = 0;
    insect.speedY = -1;

    vx = 0;
    vy = 0;

    phase = random(TWO_PI);
    driftPhase = random(TWO_PI);
  }

  void update() {
    if (finished) return;

    int elapsed =
      millis() - animationStartTime - delayMs;

    // Unreleased lights continue drifting in the jar.
    if (elapsed < 0) {
      source.update();

      x = jarX + source.x * jarScale;
      y = jarY + source.y * jarScale;
      return;
    }

    // Lock this glow to its current position for its release.
    if (!releaseStarted) {
      x = jarX + source.x * jarScale;
      y = jarY + source.y * jarScale;

      startX = x;
      startY = y;

      releaseStarted = true;
    }

    int transformEnd =
      releaseGlowDuration + releaseTransformDuration;

    int gatherEnd =
      transformEnd + releaseGatherDuration;

    int transitEnd =
      gatherEnd + releaseTransitDuration;

    // Hold position while the light becomes an insect.
    if (elapsed < transformEnd) {
      insect.speedX = 0;
      insect.speedY = -1;
      return;
    }

    // STAGE 1:
    // Move toward the center of the jar's neck.
    if (elapsed < gatherEnd) {
      float t = constrain(
        (elapsed - transformEnd)
          / (float) releaseGatherDuration,
        0,
        1
      );

      // Smoothstep easing.
      t = t * t * (3 - 2 * t);

      float oldX = x;
      float oldY = y;

      x = lerp(startX, jarX, t);
      y = lerp(
        startY,
        jarY - 35 * jarScale,
        t
      );

      insect.speedX = x - oldX;
      insect.speedY = y - oldY;

      if (abs(insect.speedX) < 0.01 &&
          abs(insect.speedY) < 0.01) {
        insect.speedX = 0;
        insect.speedY = -1;
      }

      return;
    }

    // STAGE 2:
    // Travel straight up through the jar opening.
    if (elapsed < transitEnd) {
      float t = constrain(
        (elapsed - gatherEnd)
          / (float) releaseTransitDuration,
        0,
        1
      );

      float oldY = y;

      x = jarX;
      y = lerp(
        jarY - 35 * jarScale,
        jarY - 65 * jarScale,
        t
      );

      insect.speedX = 0;
      insect.speedY = y - oldY;

      return;
    }

    // STAGE 3:
    // The firefly is now above the rim and can drift freely.
    if (!escaping) {
      escaping = true;

      vx = random(-1.0, 1.0);
      vy = random(-2.2, -1.7);
    }

    driftPhase += 0.035;

    vx += sin(driftPhase) * 0.025;
    vy -= 0.008;

    vx = constrain(vx, -1.8, 1.8);
    vy = constrain(vy, -3.2, -0.8);

    x += vx + sin(driftPhase * 1.4) * 0.3;
    y += vy + cos(driftPhase) * 0.15;

    insect.speedX = vx;
    insect.speedY = vy;
    insect.phase += insect.pulseSpeed;
    insect.wingPhase += 0.20;

    if (x < -60 || x > width + 60 ||
        y < -60 || y > height + 60) {
      finished = true;
    }
  }

  void display() {
    if (finished) return;

    int elapsed =
      millis() - animationStartTime - delayMs;

    // Waiting lights use their original JarGlow appearance.
    if (elapsed < 0) {
      source.display(jarX, jarY, jarScale);
      return;
    }

    int transformEnd =
      releaseGlowDuration + releaseTransformDuration;

    int gatherEnd =
      transformEnd + releaseGatherDuration;

    int transitEnd =
      gatherEnd + releaseTransitDuration;

    // Fade the dot as the insect emerges.
    float transform = constrain(
      (elapsed - releaseGlowDuration)
        / (float) releaseTransformDuration,
      0,
      1
    );

    float pulse =
      0.8 + 0.2 * sin(millis() * 0.012 + phase);

    float remainingGlow = 1 - transform;
    float glowSize = 4.5 * pulse;

    pushStyle();
    noStroke();

    fill(
      red(glowColor),
      green(glowColor),
      blue(glowColor),
      35 * remainingGlow
    );
    ellipse(x, y, glowSize * 5, glowSize * 5);

    fill(
      red(glowColor),
      green(glowColor),
      blue(glowColor),
      100 * remainingGlow
    );
    ellipse(x, y, glowSize * 2.5, glowSize * 2.5);

    fill(
      red(glowColor),
      green(glowColor),
      blue(glowColor),
      230 * remainingGlow
    );
    ellipse(x, y, glowSize, glowSize);

    popStyle();

    // Scale the insect down inside the jar and through the neck.
    float insectScale;

    if (elapsed < transformEnd) {
      insectScale = 0.55 * transform;

    } else if (elapsed < gatherEnd) {
      insectScale = 0.55;

    } else if (elapsed < transitEnd) {
      float t = constrain(
        (elapsed - gatherEnd)
          / (float) releaseTransitDuration,
        0,
        1
      );

      insectScale = lerp(0.55, 0.38, t);

    } else {
      // Grow back to full size after emerging.
      float t = constrain(
        (elapsed - transitEnd) / 450.0,
        0,
        1
      );

      insectScale = lerp(0.38, 1.0, t);
    }

    if (insectScale > 0) {
      float savedX = insect.x;
      float savedY = insect.y;

      insect.x = 0;
      insect.y = 0;

      pushMatrix();
      translate(x, y);
      scale(insectScale);
      insect.display();
      popMatrix();

      insect.x = savedX;
      insect.y = savedY;
    }
  }
}

class JarGlow {
  float x, y;
  float vx, vy;
  float radius;
  float phase;
  float pulseSpeed;
  int glowColor;

  JarGlow(int c) {
    glowColor = c;

    // Start at a random position inside the jar.
    x = random(-18, 18);
    y = random(-24, 24);

    // Gentle drifting movement.
    vx = random(-0.45, 0.45);
    vy = random(-0.4, 0.4);

    radius = random(2.5, 4.0);
    phase = random(TWO_PI);
    pulseSpeed = random(0.035, 0.07);
  }

  
  void update() {
    x += vx;
    y += vy;
  
    // Gentle wandering
    vx += random(-0.035, 0.035);
    vy += random(-0.035, 0.035);
  
    vx = constrain(vx, -0.35, 0.35);
    vy = constrain(vy, -0.30, 0.30);
  
    // Tighter bounds to keep the lights away from the glass.
    // The outer glow has a diameter of 5 * radius,
    // so reserve room for it on every side.
    float outerGlowRadius = radius * 2.5;
  
    float boundX = max(0, 15 - outerGlowRadius);
    float boundY = max(0, 22 - outerGlowRadius);
  
    x = constrain(x, -boundX, boundX);
    y = constrain(y, -boundY, boundY);
  
    phase += pulseSpeed;
  }
  
  
  void display(float jarCenterX, float jarCenterY, float jarScale) {
    float drawX = jarCenterX + x * jarScale;
    float drawY = jarCenterY + y * jarScale;
    float r = radius * jarScale;
    float pulse = 0.75 + 0.25 * sin(phase);
  
    noStroke();
  
    // Soft outer glow
    fill(
      red(glowColor),
      green(glowColor),
      blue(glowColor),
      30 * pulse
    );
    ellipse(drawX, drawY, r * 5, r * 5);
  
    // Inner glow
    fill(
      red(glowColor),
      green(glowColor),
      blue(glowColor),
      85 * pulse
    );
    ellipse(drawX, drawY, r * 2.5, r * 2.5);
  
    // Bright center
    fill(
      red(glowColor),
      green(glowColor),
      blue(glowColor),
      230
    );
    ellipse(drawX, drawY, r, r);
  }

}
