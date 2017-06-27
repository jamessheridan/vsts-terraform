Trace-VstsEnteringInvocation $MyInvocation

function get_terraform
{
  $terraform_path = "c:\terraform-dl"
  $terraform_version = Get-VstsInput -Name Version
  $terraform_baseurl = "https://releases.hashicorp.com/terraform/"

  If (Test-Path $terraform_path){
    Write-Output "Terraform already installed on agent"
    $P = [Environment]::GetEnvironmentVariable("PATH")
    if($P -notlike "*"+$terraform_path+"*")
    {
        [Environment]::SetEnvironmentVariable("PATH", "$P;$terraform_path")
    }
    terraform -version
  } Else {
    $regex = """/terraform/([0-9]+\.[0-9]+\.[0-9]+)/"""
    $web = New-Object Net.WebClient
    $webpage = $web.DownloadString($terraform_baseurl)
    $versions = $webpage -split "`n" | Select-String -pattern $regex -AllMatches | % { $_.Matches | % { $_.Groups[1].Value } }
    $latest = $versions[0]
    if ($version -eq "latest")
    {
        $version = $versions[0]
    }
    else
    {
        if (-not $versions.Contains($terraform_version))
        {   
            throw [System.Exception] "$terraform_version not found."    
        }
    }

    $tempfile = [System.IO.Path]::GetTempFileName()
    $source = $terraform_baseurl+$terraform_version+"/terraform_"+$terraform_version+"_windows_amd64.zip"
    Write-Host "Installing Terraform from $source..."
    Invoke-WebRequest $source -OutFile $tempfile
    if (-not (test-path $terraform_path))
    {
        mkdir $terraform_path
    }
    $P = [Environment]::GetEnvironmentVariable("PATH")
    if($P -notlike "*"+$terraform_path+"*")
    {
        [Environment]::SetEnvironmentVariable("PATH", "$P;$terraform_path")
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
    Unzip $tempfile $terraform_path
    Write-Output "Terraform version:"
    terraform --version
  }
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
