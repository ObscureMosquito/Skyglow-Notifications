<div align="center">
<h1>Skyglow Notifications Daemon</h1>
<img src="icon.png" width=20% height=20%>
</div>

Simple Cydia Tweak that will open a low power TCP socket and constantly listen for push notifications when deemed appropriate (when network is available as an example), this is made us an alternative to Apple Push Notification Service, adding just a tiny bit of unnoticeable battery overhead, allowing you to host your own free notification server.

## Usage
You will need to download and install the tweak, set up the server with your credentials and point the client to the server via the settings panel.

## Features
The best part of this tweak is it simplicity, it can be easily adapted to work with one or multiple services, allowing users to have notifications in their old iDevices easily, by listening for multiple notification for different apps in the same tweak.

By default, the server will store any missed notifications and the client will be sent them when they reconnect in the next available window.