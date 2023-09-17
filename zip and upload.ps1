# Pre-reqs
# Install-Module -Name Posh-SSH
# Install-Module CredentialManager
# Run this first:

# Create encrypted-pass.txt. Only need do this once. Here for reference.
# read-host -assecurestring | convertfrom-securestring | out-file encrypted-pass.txt

# Set up some vars
$server = "INPUT SERVERNAME HERE"
$sftpdest = "INPUT REMOTE DIRECTORY HERE e.g. /var/www/downloads"
$username = "INPUT USERNAME HERE e.g. root"
$item1 = "INPUT LOCAL EXPORT DIRECTORY #1 NAME HERE FullRes-Suitable-For-Print"
$item2 = "INPUT LOCAL EXPORT DIRECTORY #1 NAME HERE MediumRes-Suitable-For-Web"
$fileprefix = "ENTER ZIP FILENAME PREFIX e.g. jill-bloggs-photography"
$cc = "ENTER AN EMAIL ADDRESS TO CC, EMPTY STRING OK"
$urlpath = "ENTER URL TO UPLOAD PATH e.g. www.jillbloggsphotography.com/download"
$myname = "ENTER NAME AT BOTTOM OF EMAIL e.g. Jill"

# Let's first setup the SFTP Session. If this fails, there is no point in going further:

Try {
    Write-Host -NoNewline " -- Connecting to $server (timeout = 5s)... "
    $password = Get-Content 'encrypted-pass.txt' | ConvertTo-SecureString
    $cred = new-object -typename System.Management.Automation.PSCredential `
             -argumentlist $username, $password
    $SFTPSession = New-SFTPSession -ComputerName $server -Credential $cred -ConnectionTimeout 5 -ErrorAction stop
} Catch {
    Write-Host "FAILED :(" -ForegroundColor Red
    Exit
}
Write-Host " CONNECTED" -ForegroundColor Green

$retries = 3

# Verify existence of BOTH exported directories (medium res / full res files)
if (-NOT (Test-Path -Path $item1) -OR -NOT (Test-Path -Path $item2)) {
    Write-Host " -- Export directories missing" -ForegroundColor Red
    Exit
} else {
    $highrescount = (gci -Path $item1 | measure).Count
    $medrescount = (gci -Path $item2 | measure).Count
    $totalcount = $highrescount + $medrescount
    Write-Host " -- $totalcount Source files found"
    Write-Host " -- $highrescount High res"
    Write-Host " -- $medrescount Medium res"
}

if ($highrescount -eq 0) {
    Write-Host " -- Exiting, as no HIGH res files found" -ForegroundColor Red
    Exit
}
if ($medrescount -eq 0) {
    Write-Host " -- Exiting, as no MEDIUM res files found" -ForegroundColor Red
    Exit
}

# Request client name from user
$clientname = Read-Host "Please enter client name e.g. joebloggs - no spaces just letters"

# Obtain all filenames for this client (format = "jill-bloggs-photography-clientname-001.zip")
$check = $fileprefix + $clientname + "*"

# How many existing files? Return a measurement object
$measurement = gci -Filter $check -Name | `
foreach {
    $nameArray = $_.Split("-")
    Write-Output $nameArray[4].Split(".")[0].trimstart("0")
}  | measure -Maximum

if ($measurement.Count -eq 0)
{
    Write-Host " -- No existing files for this client name found, let's start at index 001."
    $newindex = 1
} else {
    $newindex = $measurement.Maximum + 1 # don't use the total count, use the highest number
    Write-Host " -- There were" $measurement.Count "existing files."
}

$newindex = ([string]$newindex).PadLeft(3,'0')
$newfilename = "$fileprefix-$clientname-$newindex.zip"
Write-Host -NoNewline " -- Zipping $newfilename... "

$compress = @{
  Path = $item1, $item2
  CompressionLevel = "Fastest"
  DestinationPath = $newfilename
}
Compress-Archive @compress

Write-Host "DONE" -ForegroundColor Green

# Upload the file
$testpath = $sftpdest + $newfilename

Write-Host -NoNewline "Uploading $newfilename... "

Set-SFTPItem -SessionId $SFTPSession.SessionId -Path $newfilename -Destination $sftpdest
$success = Test-SFTPPath -SessionId $SFTPSession.SessionId -Path $testpath

if ($success) {
    ## Upload went ok
    Write-Host "Upload OK" -ForegroundColor Green

} else {
    ## Upload failed, try again x times
    Write-Host "Upload FAILED" -ForegroundColor Red
    for ($num = 1 ; $num -le $retries ; $num++) {
        Write-Host "Re-upload attempt " $num
        Set-SFTPItem -SessionId $SFTPSession.SessionId -Path $newfilename -Destination $sftpdest
        $success = Test-SFTPPath -SessionId $SFTPSession.SessionId -Path $testpath
        Write-Host "Uploaded: " $success
        if ($success) { $num = $retries + 1 }
    }
}

if ($success) {
    ## FILE UPLOAD OK

    # List directory contents
    Get-SFTPChildItem -SessionId $SFTPSession.SessionId -Path $sftpdest | sort -property Fullname | ft -Property Name,LastAccessTime,Length

    # Display file sizes
    $remotefileobject = Get-SFTPChildItem -SessionId $SFTPSession.SessionId -Path $sftpdest | Where-Object {$_.Name -like $newfilename}
    $localfileobject = Get-Item $newfilename
    $remotefilesize = $remotefileobject.Length
    $localfilesize = $localfileobject.Length

    Write-Host "$newfilename (local) size:  $localfilesize"
    Write-Host "$newfilename (remote) size: $remotefilesize"
    if ($remotefilesize -eq $localfilesize) {
        Write-Host "Looks ok to me" -ForegroundColor Green
    } else {
        Write-Host "Doesn't look right" -ForegroundColor Red
    }
    $confirm = Read-Host "Delete source folders? (y/n)"
    if ($confirm -eq "y") {
        # Delete the folders
        Remove-Item $item1 -Recurse -Force -Confirm:$false
        Remove-Item $item2 -Recurse -Force -Confirm:$false
    }
    $confirm = Read-Host "Want me to create the email? (y/n)"
    if ($confirm -eq "y") {
        $emailto = Read-Host "Email address (/enter = blank)"
        $name = Read-Host "Dear who? (/enter = blank)"

        # filesize in friendly format
        $remotefilesize = [math]::Round($remotefilesize/1MB,1)
        $newline = "%0d%0a"
        $newpara = "%0d%0a%0d%0a"
        # Create the email
        $email = "mailto:" + $emailto + "?Subject=Edited photos ready to download&Cc=" + $cc + "&Body=Dear $name,$newpara"
        $email += "Please find below a link to download the edited photos. I hope you love the finished results!$newpara"
        $email += "Here's the link: $urlpath/$newfilename $newpara"
        $email += "Info about your download (please check numbers look correct)$newline"
        $email += "- Photo count: $highrescount in high res and $medrescount in medium res.$newline"
        $email += "- These numbers may include different versions for e.g. crop or colour.$newline"
        $email += "- File size: $remotefilesize MB$newpara"
        $email += "Viewing / Storing your photos$newline"
        $email += "The photos are delivered as a single zipped file to make downloading and storing more straightforward. "
        $email += "Please don't forget to unzip the file (right-click, extract all, then follow the prompts) before attempting to view the photos. "
        $email += "We also encourage you to keep the file in a safe place for your future use. If you must use a USB stick or external drive to backup, do so in triplicate; external disks eventually break.$newpara"
        $email += "Standard Delivery Terms$newline"
        $email += "All downloads will expire after 30 days. This email constitutes delivery of the finished product or part thereof. "
        $email += "We always do our best to accommodate requests to re-deliver, but we do not guarantee this.$newpara"
        $email += "With best wishes,$newpara"
        $email += $myname
        Start-Process $email
    }
} else {
    Write-Host "We were ultimately not successful. Check all files left intact, e.g. remove $newfilename"
}

Remove-SFTPSession -SessionId $SFTPSession.SessionId