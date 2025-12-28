// Bibliothèque - librairies - imports
import processing.net.*;
import http.requests.*;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import javax.imageio.ImageIO;
import java.util.Base64;
import javax.swing.JOptionPane;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import com.google.zxing.*;
import com.google.zxing.common.*;
import com.google.zxing.qrcode.*;
import java.awt.image.BufferedImage;

// Connexion TCP - client - serveur
Server myServer;
Client client;
// Le port connectant le serveur et le client.
int port = 8888;

// Information Github
// le token est le code d'accès obtenu sur github.
String token = "";
// pseudo est le nom d'indentifiant du compte github.
String pseudo = "vtp-mv";
// repository est le nom du dépot utiliser pour héberger les images.
String repository = "ImageGant";
// branch est le nom de la branche utiliser dans le dépot. 
String branch = "main";

// Logo
// logoCopyright est le petit logo vestechpro qui apparait sur l'image à la toute fin. 
String logoCopyright = "Logo/Copyright2.png";
// logoDepart est l'image lorsque le code est exéctuter. 
String logoDepart = "Logo/FondDepart4.jpg";
// Initialisation des logo
PImage imageDepart;
PImage imageCopyright;

// Couleur RGB ( Red, Green, Red ) 
// couleurBAS
color couleurBAS = color(52, 121, 207);
// couleurHAUT/rose
color couleurHAUT = color(255, 25, 110);

// Initialisation de l'image
// Partie dessin. 
PGraphics artLayer;
// Partie graphique.
PGraphics graphLayer;
// Partie Texte
PGraphics textLayer;
// Hauteur du graphique
int graphHauteur ;
// Hauteur du dessin
int artHauteur ;
// Grosseur (horizontal) du texte
int texteHorizontal;

// Initialisation pour l'hebergement de l'image
PImage imageToUpload;

// Initialisation du popup
boolean popupShown = false;

// Les donnees des graphique se met a jours a chaque 3 secondes.
int frameSkip = 1; 
boolean graphNeedsUpdate = true;
float prevGsrY, prevPulseY, prevBpmY;
boolean isFirstGraphPoint = true;
float graphX = 0;     
float graphStep = 2;

// Battement par minute
int BPM;

// Rythme cardiaque - Pouls 
int pulseValue;
int avgPulse = 0;

// GSR / Conductivité
int gsrValue;

// Calcul de la moyenne 
long moyGSR = 0;
boolean moyCalculer = false;
long totalGSR = 0;
long maxGSR;
int sampleCount = 0;
long startTime;


// Initialisation des positions
float posX, posY;
float prevX, prevY;
float stepSize = 2;

// Initialisation code QR
String codeQR_Sauvegarder = "";
PImage qrImage;

// Mettre le dessin en "pause/play"
boolean imageActif = true;

// Lettre 
// Pour sauvegarder l'image
char lettreSauvegarder = ' ';
// Pour réinitialiser l'image
char lettreRestart = 'r';

// Fonction de départ. Elle initialise les composants du canvas. 
void setup() {
  // Si deux écran, rajouter un "2"
  // Ex => fullscreen(2);
  fullScreen(2);
  // Si vous préférer une fenêtre plus petite, vous pouvez décider la grandeur exacte. 
  // Ex => size(800,500);
  // Ouverture du serveur au port 8888. 
  myServer = new Server(this, port);

  imageDepart = loadImage(logoDepart);
  imageCopyright = loadImage(logoCopyright);

  posX = random(width);
  posY = random(height);
  prevX = posX;
  prevY = posY;

  artLayer = createGraphics(width, height);
  graphLayer = createGraphics(width, height);
  textLayer = createGraphics(width, height);

  artLayer.beginDraw();
  artLayer.background(255);
  artLayer.endDraw();
  
}

void draw() {

  // La hauteur du graphique est 20% de l'écran.
  // La hauteur de l'image est 80% de l'écran.
  // La grosseur du texte (horizontale) est 10% de l'écran.
  graphHauteur = int(height * 0.2);
  artHauteur = int(height * 0.8);
  texteHorizontal = int(width * 0.1);
  
  // Initialisation du serveur.
  // Initialisation des données.
  checkServerData();
  
  // Calcul du temps.
  long currentTime = millis();
   
  // Si popup ouvert, ne fait rien. 
  if (popupShown) {
    return;
  }

  // Création du fond de départ blanc. 
  background(255);

  // Affiche le logo de départ dans les premiers 10 secondes. 
  // Affiche le logo de départ tant que la moyenne n'est pas calculée.
    if (!moyCalculer) {
      if (imageDepart != null) {
        image(imageDepart, 0, 0, width, height);
      }
      return;
    }

  
  // Affiche le code QR
  if (qrImage != null) {
    image(qrImage, (width - qrImage.width) / 2, (height - qrImage.height) / 2);  
    return;
  }

  // Si les données sont plus que 0, la ligne bouge. Si elle est à 0, elle ne bouge pas.
  // Step size = longueur/distance de a ligne à chaque frame. 
  if (imageActif) {
    if (gsrValue == 0) stepSize = 0;
    else stepSize = map(gsrValue, moyGSR - 100, maxGSR, 2, 6);
  }
  
  // Donnée maximale de la conductivité ( La moyenne de la conductiivité + 1200 )
  // Baisser le nombre rend le capteur plus sensible.
  // Monter le nombre rend le capteur moins sensible.
  // La capteur va de 0 a 4095,  cette derniere donnée n'est pas obtenable naturellement
  // Ainsi en choissisant la donné maximale, on rend les parametres maximale plus facile a atteindre. 
  maxGSR = moyGSR +1200;

  // Calcul pour la grosseur, l'opacité et le nombre de lignes selon la conductivité de la peau. 
  float lineWeight = constrain(map(gsrValue, moyGSR - 100, maxGSR, 1, 3), 1, 3);
  // L'opacité peut aller de 0 a 255.  0 = transparent, 255 = opaque
  float opacity = map(gsrValue, moyGSR - 100, maxGSR, 30, 60);
  float linesPerFrame = constrain(map(gsrValue, moyGSR - 100, maxGSR, (height/100), (height/20)), (height/100), (height/20));  

  // Calcul de la couleur des lignes selon le battement par minute. 
  float bpmInterpFactor = map(BPM, 75, 155 , 0, 1);
  color currentColor = lerpColor(couleurBAS, couleurHAUT, bpmInterpFactor);

  // Début de la création de l'image.
    artLayer.beginDraw();
    for (int i = 0; i < linesPerFrame; i++) {
    float angle = random(TWO_PI);
    float pulseInfluence = map(pulseValue, 0, 1023, 0.5, 2.0);
    prevX = posX;
    prevY = posY;
    posX += cos(angle) * stepSize * pulseInfluence;
    posY += sin(angle) * stepSize * pulseInfluence;
    posX = constrain(posX, 0, width);
    posY = constrain(posY, 0, height);
    
    // Ombres ( Opacité est de 0.7 à 1) selon la grosseur de la ligne).
    float opacityShadow = lerp(0.7, 1, (lineWeight - 1) / 2);
    float shadow = lerp(10, 15, (lineWeight - 1) / 2);
    artLayer.stroke(red(currentColor), green(currentColor), blue(currentColor), opacityShadow);
    artLayer.strokeWeight(shadow);
    artLayer.line(prevX, prevY, posX, posY);
    
    // Lignes
    artLayer.strokeWeight(lineWeight);
    artLayer.stroke(red(currentColor), green(currentColor), blue(currentColor), opacity);
    artLayer.line(prevX, prevY, posX, posY);
  }
  artLayer.endDraw();
  
  updateText();
  updateGraphLayer();
  
  image(artLayer, 0, 0);
  noStroke();
  fill(255, 150);
  rect(0, artHauteur, width, graphHauteur);
  image(graphLayer, 0, 0);
  image(textLayer, 0,0);
}

// Fonction pour mettre le texte à jour a chaque frame. 
  void updateText(){
  textLayer.beginDraw();
  textLayer.clear();
  textLayer.fill(255, 50, 50);
  textLayer.text("Battement par minute : " + BPM, 10, height - 30);
  textLayer.fill(0, 200, 100);
  textLayer.text("Rythme cardiaque: " + pulseValue, 10, height - 50);
  textLayer.fill(0, 100, 255);
  textLayer.text("Conductivité: " + gsrValue, 10, height - 70);
  textLayer.fill(0);
  textLayer.text("Moyenne: " + moyGSR, 10, height - 90);
  textLayer.endDraw();
}

// Début de la création des graphiques.
  void updateGraphLayer() {
  graphLayer.beginDraw();
  int graphBottom = artHauteur;
  int graphTop = artHauteur + graphHauteur;
  graphLayer.strokeWeight(2);
  
  float gsrY = map(gsrValue, 0, 4095, graphTop, graphBottom);
  float pulseY = map(pulseValue, 0, 1023, graphTop, graphBottom);
  float bpmY = map(BPM, 0, 300, graphTop, graphBottom);

  if (!isFirstGraphPoint) {
    // Conductivité
    graphLayer.stroke(0, 100, 255, 170);
     graphLayer.line(graphX - graphStep + 150, prevGsrY, graphX + 150, gsrY);

    // Rythme cardiaque
    graphLayer.stroke(0, 200, 100, 170);
    graphLayer.line(graphX - graphStep + 150, prevPulseY, graphX + 150, pulseY);

    // Battement par minute
    graphLayer.stroke(255, 50, 50, 170);
    graphLayer.line(graphX - graphStep +150, prevBpmY, graphX +150, bpmY);
  } else {
    isFirstGraphPoint = false;
  }

  // Enregistre la derniere position Y pour la prochaine lignes.
  prevGsrY = gsrY;
  prevPulseY = pulseY;
  prevBpmY = bpmY;

  graphLayer.endDraw();

  // Advance graph X
  graphX += graphStep;
  if (graphX >= width -150) {
    graphX = 0;
    isFirstGraphPoint = true;
    graphLayer.beginDraw();
    graphLayer.clear(); 
    graphLayer.endDraw();
  }
}

// Fonction de depart.
// Initialisation du serveur. 
// Triage des données.
void checkServerData() {
  client = myServer.available();
  if (client != null && client.available() > 0) {
    // Sépare les données a chaque nouvelle ligne "\n"#
    String input = client.readStringUntil('\n');
    if (input != null) {
      // Sépare les données par espace " "
      String[] values = trim(input).split(" ");
      // Vérifie la longueur, doit être égal a 3. (GSR, BPM, PULSE ).
      // 0, 1, 2 = 3 .
      if (values.length == 3) {
        gsrValue = int(values[0]);
        pulseValue = int(values[1]);
        BPM = int(values[2]);
        
        // Contraindre les données à être entre deux nombres.
        // GSR ( Conductivité ) = Entre 0 et 4095.
        gsrValue = constrain(gsrValue, 0, 4095);
        // Rythme cardiaque = Entre 0 et 1023.
        pulseValue = constrain(pulseValue, 0, 1023);
        // Battement par minute = Entre 0 et 200.
        BPM = constrain(BPM, 0, 200);        
        
        // Calibration du système. 10000 = 10 secondes pour calculer une moyenne de conductivité. 
        if (millis() - startTime < 10000 && !moyCalculer && gsrValue > 0) {
          totalGSR += gsrValue;
          sampleCount++;
        } else if (millis() - startTime >= 10000 && !moyCalculer) {
          if (sampleCount > 0) {
            moyGSR = totalGSR / sampleCount;
            println("La moyenne de la conductibilité : " + moyGSR);
            moyCalculer = true;
          }
        }
      }
    }
  }
}

// Fonction pour sauvegarder l'image. 
void keyPressed() {
  if (key == lettreSauvegarder ) {
  // Sauvegarde l'image avec la date. (Année + Mois + Jour + Heure + Minute)
  String timeStamp = year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "_" + nf(hour(), 2) + "-" + nf(minute(), 2);
  String filename = "image-" + timeStamp;
  
  artLayer.beginDraw();
  
  // Rajout d'une bordure
  int borderThickness = 5;
  artLayer.stroke(0, 143, 193);
  artLayer.strokeWeight(borderThickness);
  artLayer.noFill();
  artLayer.rect(borderThickness/2.0, borderThickness/2.0, artLayer.width - borderThickness, artLayer.height - borderThickness);
 
  // Rajout du petit logo vestechpro
  if (logoCopyright == "Logo/Copyright.png"){
  float logoScale = 0.05;
  float logoW = imageCopyright.width * logoScale;
  float logoH = imageCopyright.height * logoScale;
  float logoX = (artLayer.width - logoW) -50;
  float logoY = artLayer.height - logoH - 50;
    artLayer.image(imageCopyright, logoX, logoY, logoW, logoH);
  }
  else {
  float logoScale = 0.20;
  float logoW = imageCopyright.width * logoScale;
  float logoH = imageCopyright.height * logoScale;
  float logoX = (artLayer.width - logoW) -20;
  float logoY = artLayer.height - logoH - 20;
    artLayer.image(imageCopyright, logoX, logoY, logoW, logoH);
  }
  

  
  artLayer.endDraw();

  artLayer.save("/Image/" + filename + ".png");
  background(255);

  imageActif = false;
  imageToUpload = artLayer.get(); 

  // Initialisation de la fonction pour héberger sur Github
  uploadToGitHub(imageToUpload, filename);
  }
  
  if(key == lettreRestart) {
    popupShown = true;
    int response = JOptionPane.showConfirmDialog(null, "Voulez vous créer une nouvelle image?", "Reset Confirmation", JOptionPane.YES_NO_OPTION);
    if (response == JOptionPane.YES_OPTION) {
    // Si nous cliquons sur oui, cela fait un "reset" de l'image. 
    resetSketch();
    }      
    else {
        popupShown = false; }
  }}

// Fonction pour héberger sur Github
void uploadToGitHub(PImage img, String filename) {
  String imgBase64 = encodeImageToBase64(img);
  // Sauvegarde l'image dans le dossier Images.
  String fullPath = "images/" + filename + ".png";
  // Url du site web
  String apiUrl = "https://api.github.com/repos/" + pseudo + "/" + repository + "/contents/" + fullPath;

  JSONObject json = new JSONObject();
  json.setString("message", "Image à héberger: " + filename);
  json.setString("content", imgBase64);
  json.setString("branch", branch);

  try {
    URL url = new URL(apiUrl);
    HttpURLConnection conn = (HttpURLConnection) url.openConnection();
    conn.setRequestMethod("PUT");
    conn.setRequestProperty("Authorization", "token " + token);
    conn.setRequestProperty("Content-Type", "application/json");
    conn.setDoOutput(true);

    OutputStream os = conn.getOutputStream();
    byte[] input = json.toString().getBytes("utf-8");
    os.write(input, 0, input.length);
    os.close();

    int responseCode = conn.getResponseCode();
    println("Code de réponse de github: " + responseCode);

    BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream(), "utf-8"));
    StringBuilder response = new StringBuilder();
    String responseLine = null;
    while ((responseLine = br.readLine()) != null) {
      response.append(responseLine.trim());
    }
    br.close();

    println("GitHub réponse: " + response.toString());

    JSONObject jsonResponse = parseJSONObject(response.toString());
    if (jsonResponse != null && jsonResponse.hasKey("content")) {
      JSONObject contentObject = jsonResponse.getJSONObject("content");
      String downloadUrl = contentObject.getString("download_url");
      println("Image héberger sur GitHub: " + downloadUrl);
      // Création du code QR avec le lien GitHub. 
      qrImage = createQRCode(downloadUrl);
    } else {
      println("Aucun objet trouvé dans la réponse.");
    }
  } catch (Exception e) {
    println("Problème survenu lors de l'hébergement sur GitHub: " + e.getMessage());
    e.printStackTrace();
  }
}

// Fonction pour encoder l'image. 
String encodeImageToBase64(PImage img) {
  BufferedImage bufferedImage = (BufferedImage) img.getNative();
  try (ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream()) {
    ImageIO.write(bufferedImage, "PNG", byteArrayOutputStream);
    byte[] byteArray = byteArrayOutputStream.toByteArray();
    return Base64.getEncoder().encodeToString(byteArray);
  } catch (IOException e) {
    e.printStackTrace();
    return null;  
  }
}

// Création du code QR
PImage createQRCode(String data) {
  try {
    QRCodeWriter writer = new QRCodeWriter();
    // Taille du code QR. ( 600px par 600px )
    BitMatrix matrix = writer.encode(data, BarcodeFormat.QR_CODE, 600, 600);
    PImage img = createImage(matrix.getWidth(), matrix.getHeight(), RGB);
    img.loadPixels();
    for (int x = 0; x < matrix.getWidth(); x++) {
      for (int y = 0; y < matrix.getHeight(); y++) {
        int pixelColor = matrix.get(x, y) ? color(0) : color(255);
        img.pixels[y * matrix.getWidth() + x] = pixelColor;
      }
    }
    img.updatePixels();
    return img;
  } catch (WriterException e) {
    e.printStackTrace();
    return null;
  }
}

// Fonction relié avec le bouton. 
// Pour réinitiliser l'image a 0. 
void resetSketch() {
  posX = random(width);
  posY = random(height);
  prevX = posX;
  prevY = posY;

  // Remets les données a 0.
  totalGSR = 0;
  sampleCount = 0;
  moyGSR = 0;
  startTime = millis();
  moyCalculer = false;
  qrImage = null;
  imageToUpload = null;
  codeQR_Sauvegarder = "";

  // Fond Blanc (255)
  artLayer.beginDraw();
  artLayer.background(255);
  artLayer.endDraw();
  
  startTime = millis();
  popupShown = false;
}
