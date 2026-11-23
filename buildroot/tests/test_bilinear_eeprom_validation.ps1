param([string]$SettingsPath)
$ErrorActionPreference = 'Stop'
if (-not $SettingsPath) {
  $SettingsPath = Join-Path $PSScriptRoot '../../Marlin/src/module/settings.cpp'
}

# Execute the matching-grid branch extracted from the real source. The small
# host harness models EEPROM_READ's documented !validating assignment rule.
# NaN locals deliberately expose use of values not assigned during validation.
$source = Get-Content -LiteralPath $SettingsPath -Raw
$marker = 'if (grid_max_x == (GRID_MAX_POINTS_X) && grid_max_y == (GRID_MAX_POINTS_Y))'
$start = $source.IndexOf($marker)
if ($start -lt 0) { throw 'Bilinear EEPROM load branch not found' }
$open = $source.IndexOf('{', $start)
$depth = 1
$end = $open + 1
while ($depth -gt 0 -and $end -lt $source.Length) {
  if ($source[$end] -eq '{') { $depth++ }
  if ($source[$end] -eq '}') { $depth-- }
  $end++
}
if ($depth -ne 0) { throw 'Unbalanced source branch' }
$branch = $source.Substring($open + 1, $end - $open - 2)
$branch = $branch.Replace('set_bed_leveling_enabled(false)', 'SetLeveling(false)')
$branch = $branch.Replace('EEPROM_READ(bedlevel.z_values)', 'ReadMesh()')
$code = @'
using System;
public static class BilinearEepromRegression {
  struct XY {
    public float x, y;
    public XY(float a, float b) { x=a; y=b; }
  }
  sealed class Mesh {
    public XY spacing=new XY(90.45f,92.5f), start=new XY(10,10);
    public float[,] values=new float[,] {{.20f,.0725f,.195f},{.0125f,.0125f,.070f},{.025f,.1625f,.125f}};
    public int changes;
    public void set_grid(XY s, XY o) { spacing=s; start=o; changes++; }
  }
  static Mesh bedlevel;
  static bool validating, active;
  static float z;
  static int levelChanges, reads;
  static void Reset() { bedlevel=new Mesh(); active=true; z=10; levelChanges=reads=0; }
  static void Check(bool ok,string reason) { if(!ok) throw new Exception(reason); }
  static bool Finite(float f) { return !float.IsNaN(f) && !float.IsInfinity(f); }
  static float Correction() {
    float tx=(235-bedlevel.start.x)/bedlevel.spacing.x;
    float ty=(198.3f-bedlevel.start.y)/bedlevel.spacing.y;
    int ix=Math.Max(0,Math.Min(1,(int)Math.Floor(tx)));
    int iy=Math.Max(0,Math.Min(1,(int)Math.Floor(ty)));
    tx-=ix; ty-=iy;
    return (1-ty)*((1-tx)*bedlevel.values[ix,iy]+tx*bedlevel.values[ix+1,iy])
         + ty*((1-tx)*bedlevel.values[ix,iy+1]+tx*bedlevel.values[ix+1,iy+1]);
  }
  static void SetLeveling(bool enable) {
    if(active==enable) return;
    float correction=Correction();
    Check(Finite(correction),"Position conversion used corrupt mesh geometry");
    z+=active?correction:-correction;
    active=enable; levelChanges++;
  }
  static void ReadMesh() {
    reads++;
    if(!validating) bedlevel.values=new float[,] {{.1f,.2f,.3f},{.4f,.5f,.6f},{.7f,.8f,.9f}};
  }
  static void LoadBranch(bool validation) {
    validating=validation;
    XY spacing=new XY(float.NaN,float.NaN), start=new XY(float.NaN,float.NaN);
    // settings.h EEPROM_READ_ uses writing=!validating. During validation
    // the local geometry receives no assignment; CRC reads still happen.
    if(!validating) { spacing=new XY(90.45f,92.5f); start=new XY(10,10); }
    // BEGIN_ACTUAL_BRANCH
__BRANCH__
    // END_ACTUAL_BRANCH
  }
  public static string Run() {
    Reset();
    LoadBranch(true);
    Check(bedlevel.changes==0,"Validation changed live mesh geometry");
    Check(active && levelChanges==0 && z==10,"Validation changed leveling or position");
    Check(bedlevel.values[0,0]==.20f && reads==1,"Validation must read without overwriting mesh values");

    Reset();
    float expected=10+Correction();
    LoadBranch(true);
    LoadBranch(false);
    Check(!active && levelChanges==1,"Actual load must disable leveling exactly once");
    Check(Finite(z) && Math.Abs(z-expected)<0.00001f,"Load must preserve the physical position using the old mesh");
    Check(bedlevel.changes==1 && bedlevel.spacing.x==90.45f,"Actual load did not restore geometry exactly once");
    Check(bedlevel.values[2,2]==.9f && reads==2,"Actual load did not restore mesh values");

    Reset();
    active=false;
    LoadBranch(true);
    LoadBranch(false);
    Check(Finite(z) && z==10 && levelChanges==0,"Loading with leveling already off must keep Z unchanged");
    return "PASS: validation is side-effect free; active-mesh reload keeps finite physical Z; inactive reload leaves Z unchanged.";
  }
}
'@
$code = $code.Replace('__BRANCH__', $branch)
Add-Type -TypeDefinition $code -Language CSharp
try {
  [BilinearEepromRegression]::Run()
} catch {
  Write-Output ('FAIL: ' + $_.Exception.GetBaseException().Message)
  exit 1
}
exit 0
