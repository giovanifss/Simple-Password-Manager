# Simple-Password-Manager
Simple Password Manager is a POSIX shell script able to manage passwords, relying in the gpg encryption for the 'database' security.  

### Capabilities:  
- Generate random passwords that may contain the following chars: ```A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~```  
- Add, update, query and delete a password to the pgp encrypted 'database'  

### Installation:  
To install, copy the ```password-manager.sh``` script to ```/usr/local/bin```. Note that you will (hopefully) need root permissions for that.  
Alternatively, copy the script to any other path included in PATH.  

Do not forget to ```chmod +x``` the script in the new location.  

### Usage:  
The program will ask for any missing information needed to execution. The needed information is:  
- UserID: The gpg UserID for key retrieving. You can add this information directly at the beginning of the script.  
- Database: The path to the 'database' file. This information can be passed through ```-f``` or ```--file``` parameters.  
- Service: The name of the service that uses the password (e.g. Google). This information can be passed through ```-s``` or
```--service``` parameters.  

For generation of a new password, you can use: ```password-manager generate -s Facebook -f <database>```.  

### How does it work?  
There are 5 actions supported: ```generate```, ```add```, ```update```, ```delete``` and ```query```.  

The ```generate``` action will ask for the amount of characters desired, generate the password, add the specified service and the
password to the 'database' and copy the password for the clipboard (only if ```xsel``` or ```xclip``` is installed). 

The ```add``` action will ask for the service and its respective password and add it to the 'database'.  

The ```query``` action will search in the 'database' for the specified service, if ```xsel``` or ```xclip``` is installed the
program will copy the password to the clipboard, otherwise it will be echoed to the screen.  

The ```delete``` action will delete the service desired together with its password from the 'database'.  

The ```update``` action is not implemented yet.  

All actions perform some common steps. Those steps are:  
1) Copy the database elsewhere  
2) Unlock/decrypt the copied database  
3) Delete copied database  
4) Perform actions on the plaintext  
5) Lock/encrypt the plaintext  
6) Backup original database  
7) Move the new database to the original database\`s path  

### Dependencies:
The program has some dependencies for execution:  
- ```GnuPG```  
- ```tr``` and ```fold```
- ```xsel``` or ```xclip``` (For automatic clipboard copy - *OPTIONAL*)
