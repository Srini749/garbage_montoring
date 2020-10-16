# Garbage Monitoring Application Using Flutter

# Goal
To increase time efficiency and save fuel through the creation of optimized routes for garbage disposal. It was designed with keeping garbage disposing truck drivers in mind.

![Screenshot_2020-10-16-10-21-22-940_com example garbage_monitoring 1](https://user-images.githubusercontent.com/60594770/96215119-b7ebdb80-0f9a-11eb-8813-bdf94403cdb9.jpg)

# What it Does?
It creates an optimized route, on the basis of data stored on firestore database, between smart dustbins, distrubuted over a region, in such a way that that the route consists of only dustbins to be disposed. 

# Process
- Each Smart Dustbin consists of a ultrasonic sensor which determines its statusi.e how much of the bin is filled, as a double. It is assumed that if the status is greater than a threshold value(75.0 in this case), the corresponding bin has to be disposed. Each bin then communicates with the Firestore database an uploads its status along with its location to the database.
- The firestore data is used to show the bins as markers on the google map. Red bins indicate a status of less than 75 and green bins indicated bins with status of more than 75 i.e to be disposed.
- This firestore data is used by the application to draw polylines on the google map such that the polylines are only created for the green bins and the red bins are not considered for route creation.
- The route is created w.r.t to the current location of the user everytime the "GET ROUTE" button is clicked on the application.

# Benefits 
- The application saves the user time and energy. The manual checks on a regular basis are no longer required. Disposal timings can be optimized through this app.
- By clearly indicating which bins are to be disposed and which are not, a lot of fuel is saved.


