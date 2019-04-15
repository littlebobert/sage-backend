var firebaseConfig = {
  apiKey: "AIzaSyA05-sr91RcQG6UEdCvHH3rjxqCuZdtAW8",
  authDomain: "sage-236402.firebaseapp.com",
  databaseURL: "https://sage-236402.firebaseio.com",
  projectId: "sage-236402",
  storageBucket: "sage-236402.appspot.com",
};
// Initialize Firebase
firebase.initializeApp(firebaseConfig);

var provider = new firebase.auth.TwitterAuthProvider();

function updateWithDisplayName(displayName) {
  var content = document.getElementById("content");
  
  var displayNameSection = document.createElement("div");
  displayNameSection.innerText = displayName;
  content.appendChild(displayNameSection);
  
  var button = document.createElement("button");
  button.onclick = function() { signOut(); };
  button.innerText = "Sign out";
  var signOutSection = document.createElement("div");
  signOutSection.appendChild(button);
  content.appendChild(signOutSection);
}

function createSignInSection() {
  var content = document.getElementById("content");
  var signInSection = document.createElement("div");
  var signInButton = document.createElement("button");
  signInButton.innerText = "Sign in with Twitter";
  signInButton.onclick = function() { startSignIn(); }
  signInSection.appendChild(signInButton);
  content.appendChild(signInSection);
}

function startSignIn() {
  firebase.auth().useDeviceLanguage();
  firebase.auth().signInWithRedirect(provider);
}

function onLoad() {
  firebase.auth().getRedirectResult().then(function(result) {
    if (result.credential) {
      // This gives you a the Twitter OAuth 1.0 Access Token and Secret.
      // You can use these server side with your app's credentials to access the Twitter API.
      var token = result.credential.accessToken;
      var secret = result.credential.secret;
    }
    var user = result.user;
    if (user == null) {
      if (firebase.auth().currentUser == null) {
        startSignIn();
        return;
      }
      updateWithDisplayName(firebase.auth().currentUser.displayName);
      return
    }
    updateWithDisplayName(user.displayName);
  }).catch(function(error) {
    // Handle Errors here.
    var errorCode = error.code;
    var errorMessage = error.message;
    alert("Received an error in processing redirect: " + errorMessage);
    // The email of the user's account used.
    var email = error.email;
    // The firebase.auth.AuthCredential type that was used.
    var credential = error.credential;
  });
}

function signOut() {
  firebase.auth().signOut().then(function() {
    var content = document.getElementById("content");
    content.innerHTML = "";
    createSignInSection()
  }).catch(function(error) {
    alert("Failed to sign out: " + error.message);
  });
}