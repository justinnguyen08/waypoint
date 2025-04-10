Contributions:

Tony Ngo (Release 25%, Overall 25%)
Added Leaderboard pages with mock data
Created Tab Bar Controller that spans to all pages
Created Login and Create Account pages
I worked on daily challenges, monthly challenges, and the feed of challenges.
I worked on the leaderboard with a point system derived from the challenges. You can look at what your friends have or on a global scale.
I implemented the daily photo streak.
I worked on the Firebase to ensure that challenge images and other metadata is stored.
I ensured that when the app is loaded up the first page is the map page.
Helped set up the firebase collection.


Justin Nguyen (Release 25%, Overall 25%)
Created Profile page which segues into the Map Collection page and simulates the view of a user's profile
Created Settings page which integrates both Profile Settings and Yearly Timelapse pages
Worked on user interface for all pages, including constraints, designs, and icons
Set up Firebase user collection
Created a connection between Profile data labels and Firebase Firestore to dynamically update
Developed Settings functionality
Contributed to Registering and Login screens to verify accounts are unique for proper authentication

Tarun Somisetty (Release 25%, Overall 25%)
Added Map Pages with simulated location as the main location
Added Friends pages with functionality allowing for toggling between suggested and current friends and changing the profile screen based on which cell in table view is clicked. 
I worked on making all the friends pages, from being able to add friends/remove friends/have pending friends. 
Having all this reflected accurately on the Firestore database
Made sure all the storyboards for the add/remove/pending retrieve all the data properly from photos and username to the number of friends and streak
Helped Pranav for the setup of the map screen
Organizing photo / metadata storage for Firebase (daily, pinned, profile, etc.)

Pranav Sridhar (Release 25%, Overall 25%)
Learned to use AVFoundation
Added Camera pages: Open Camera, and Camera Views
Added Tag Friends page to Cam page
organizing photo / metadata storage for Firebase (daily, pinned, profile, etc.)
retrieve and display daily and pinned photos on map for user and friends, at correct locations (coordinates)
created functionality to take, upload, and display profile picture on map and profile views
retrieve and display ALL user photos on their own profile
retrieve and display profile, daily, and pinned photos when looking at friend’s profile

Known Bugs:
Flickering of friend pending/add/remove buttons flicker on the friend page on the xcode simulator but not seen on a physical phone.
When first looking at the leaderboard, the current user may show up multiple times under the friends tab. When switching from tab to tab you only show up once. This was working before, but for some unknown reason it stopped.

Deviations:
Removed toggling Light Mode. Because the app is automatically configured to be Light Mode or Dark mode based on the phone’s settings, we were unsure whether it would make sense to ignore those settings or not. 
Horizontal View constraints. We decided that it does not make sense for our app. We will restrict to portrait mode. We will fix all of our constraints for the final.


