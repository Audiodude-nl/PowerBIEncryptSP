A powershell script that utilizes some of the SDK code from the PowerBI c# SDK and the undocumented API v2 to update and create credentials for SQL datasources on an on premise data gateway using Service Principals for auth.

This code might be useful until MS makes the V2 API public.

You first need to build the dll file from the C# code.
a dll is in the repo, but if you worry about that, build it yourself. :-) 
c# Code is included.

The powershell commands are the same as the (old) way of doing it with the (4.2 PowerBI_C# SDK) 

References: 
https://github.com/microsoft/PowerBI-CSharp
https://github.com/microsoft/PowerBI-Developer-Samples/blob/master/PowerShell%20Scripts/EncryptGatewayCredentials.ps1

But I've added the Service Principal Support. . Which was before not in the SDK. 
(That was the only reason I did this project.)

Took me a bit of time to figure out how to encrypt and how the API was working. 

(Never done a C# project before, so I hope you forgive my crude way of ripping out the important parts and adding the new parts.)

