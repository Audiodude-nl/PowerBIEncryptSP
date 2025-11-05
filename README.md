A powershell script that utilizes some of the SDK code from the PowerBI API to update and create SQL datasources on a gateway using Service Principals for auth.
Using the undocumented PowerBI API v2. 
This code might be useful until MS makes the V2 API public.

You first need to build the dll file from the C# code.
a dll is in the repo, but if you worry about that, build it yourself. :-) 
c# Code is included.

The powershell commands are the same as the (old) way of doing it with the (4.2 PowerBI_C# SDK) https://github.com/microsoft/PowerBI-CSharp
But I've added the possibility of using Service Principals. Which was before not in the SDK.

Took me a bit of time to figure out how to encrypt and how the API was working. 

(Never done a C# project before, so I hope you forgive my crude way of ripping out the important parts and adding the new parts.)

