Trace-VstsEnteringInvocation $MyInvocation

function get_terraform
{
    $version = Get-VstsInput -Name Version
    $terraformbaseurl = "https://releases.hashicorp.com/terraform/"
    $path = "c:\terraform-download"
    $regex = """/terraform/([0-9]+\.[0-9]+\.[0-9]+)/"""
    $web = New-Object Net.WebClient
    $webpage = $web.DownloadString($terraformbaseurl)
    $versions = $webpage -split "`n" | Select-String -pattern $regex -AllMatches | % { $_.Matches | % { $_.Groups[1].Value } }
    $latest = $versions[0]
    if ($version -eq "latest")
    {
        $version = $versions[0]
    }
    else
    {
        if (-not $versions.Contains($version))
        {   
            throw [System.Exception] "$version not found."    
        }
    }

    $tempfile = [System.IO.Path]::GetTempFileName()
    $source = "https://releases.hashicorp.com/terraform/"+$version+"/terraform_"+$version+"_windows_amd64.zip"
    Write-Host "Installing Terraform from $source..."
    Invoke-WebRequest $source -OutFile $tempfile
    if (-not (test-path $path))
    {
        mkdir $path
    }
    $P = [Environment]::GetEnvironmentVariable("PATH")
    if($P -notlike "*"+$path+"*")
    {
        [Environment]::SetEnvironmentVariable("PATH", "$P;$path")
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    function Unzip
    {
        param([string]$zipfile, [string]$outpath)
        if (test-path $outpath)
        {
            del "$outpath\*.*"
        }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
    }
    Unzip $tempfile $path
    Write-Output "Terraform version:"
    terraform --version
}

function run_terraform
{
    $argumentents = Get-VstsInput -Name Arguments -Require
    
    Write-Host "Running: terraform $argumentents"
    terraform $argumentents

    if ($LASTEXITCODE)
    {
        $E = $Error[0]
        Write-Host "##vso[task.logissue type=error;] Terraform failed to execute. Error: $E" 
        Write-Host "##vso[task.complete result=Failed]"
    }
}

function prepare
{
    $runpath = Get-VstsInput -Name RunPath -Require
    Write-Host "Using $runpath to Terraform from."
    cd $runpath
}

Write-Host "Preparing..."
prepare
Write-Host "Finding and/or Downloading Terraform..."
get_terraform
Write-Host "Running Terraform..."
run_terraform
Write-Host "All done!" 
