# Advanced Zip and Upload Powershell Script
May be of use to photographers / consultants / anyone who regularly delivers sets of files to customers over SFTP

## The problem
Lightroom's photo export function allows you to create various export profiles, and then tick any number of those to export a given set out to different formats, naming conventions, whatever:
![image](https://github.com/hazymat/advanced-zip-and-upload/assets/7063284/11119263-4776-4c22-91f1-4ccbf3d2447a)

I was regularly exporting two sets of photos for clients, medium res and high res - each to its own clearly labeled folder. Then I was zipping both folders up, and uploading to an SFTP server, then emailing the customer with a link to download the files.

If done well, the process above can be really time consuming. For example;
- you may wish to keep a local copy of recent exports so they can be checked later / re-sent. This necessitates numbering the zip files sequentially, naming them consistently, etc.
  - (added workflow bonus: quickly see how many exports you've done for a given client recently, based on file creation dates etc.)
- you may wish to let the email recipient / customer know how many photos to expect, what the zip file's size is, as well as other templatable things that apply to all customers
- you may wish to perform checks to ensure the file was uploaded without error before sending the email
- you may also want to check the Lightroom export went without hitch, by verifying the number of files in each subfolder match
- you may wish to avoid using a GUI FTP client as it can be cumbersome
- you may wish to ensure the source files are deleted at the end of the process and only once you have confirmed everything looks okay. This is especially important to ensure you don't have leftover files from one client that accidentally get added to the upload for the next client

## First time setup
- Download the script and store in a chosen folder
- In powershell run:
  - `Install-Module -Name Posh-SSH`
  - `Install-Module CredentialManager`
  - `read-host -assecurestring | convertfrom-securestring | out-file encrypted-pass.txt` - type in the password for the credential used to access your SFTP server, and it will be stored locally, securely
- Change variables at top of powershell script, examples provided
- Edit to suit your needs, e.g. to cater for more than two sets of files

## Use
- Export photos into two subfolders of the main folder where script is stored. E.g. folders represent different versions of the files
- Launch the powershell script and it guides you through the following process:
  - it quickly connects to the SFTP server to ensure there's a connection before continuing
  - it verifies you have exported files to the correct named folders before continuing
  - it asks for the name of your client each time, enter something like "microsoft" or "jamesbloggs" - this will form the filename so avoid spaces / special characters
  - it checks your local directory for previous exports for that client (e.g. jillbloggs-photography-microsoft-004) and increments that number
  - it creates your zip file and uploads it straight away
  - it handles any failed upload attempts with timeouts / retries
  - after upload it lists files in the remote directory to show their dates and sizes, just to be useful
  - it looks for the new file on your SFTP server and checks its size against the new local file
  - it shows you the results and asks you to confirm everything looks ok
  - it prompts you for an email address and name to send the recipient notification email to
  - uses your default mail client to send the email. In my case I use Windows Mail ([why on earth would I do that?](https://hazymat.co.uk/2023/02/why-windows-mail-is-actually-good/comment-page-1/)) so it prompts me which account I want to send from, and includes my HTML sig already setup in Win Mail
 
If any of the checks fail, it leaves files intact and provides a handy message saying what happened so you can check the files yourself.
