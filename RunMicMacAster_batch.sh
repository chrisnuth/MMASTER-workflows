# Put all the L1A zip files in a folder, then, from that folder, call something like: 
# RunMicMacAster_batch.sh -z "4 +north"
# extra options :  -t 30 -n false -c 0.7 -w false -f 1

utm_set=0
polar_set=0
run_clean=1
run_again=1
CorThr=0.7
SzW=5
nameWaterMask=false #default no water mask
NoCorDEM=false #default don't compute uncorrected DEM
ZoomF=1 #this has to be passed to PostProcessMicMac, and WorkFlowPt2
RESTERR=30
do_ply=false #default no ply point cloud generation
do_angle=false
fitVersion=2

# figure out what options we were passed: 
#":hz:wnc:f:t:pr" 
while getopts "z:o:c:q:w:nf:t:yai:prh" opt; do
  case $opt in
    h)
      echo "Run the MicMac-based ASTER DEM pipeline from start to finish."
      echo "Call from the the directory where your zip and .met files are."
      echo "usage: RunMicMacAster_batch.sh -z 'UTMZONE' -f ZOOMF -t RESTERR -wrph"
      echo "    -z UTMZONE      : Use UTM Zone of area of interest. Takes form 'NN +north(south)'"
      echo "    -o PolarStereo  : Use polar stereo (option N for north EPSG:3411 or S for south EPSG:3412)"
      echo "    -c CorThr       : Correlation Threshold for estimates of Z min and max (optional, default : 0.7)"
      echo "    -q SzW          : Size of the correlation window in the last step (optional, default : 2, mean 5*5)"
      echo "    -w              : Name of shapefile to skip masked areas (usually water, this is optional, default : false)."
      echo "    -n NoCorDEM     : Compute DEM with the uncorrected 3B image (computing with correction as well)"
      echo "    -f ZOOMF        : Run with different final resolution   (optional; default: 1)"
      echo "    -t RESTERR      : Run with different terrain resolution (optional; default: 30)"
      echo "    -y do_ply       : Write point cloud (DEM drapped with ortho in ply)"
      echo "    -a do_angle     : Compute track angle along orbit"
      echo "    -i fitVersion   : Version of Cross-track FitASTER to be used (Def 2, 1 availiable)"
      echo "    -p  	        : Purge results and run fresh from .zip files."
      echo "    -r  	        : Re-process, but don't purge everything."
      echo "    -h  	        : displays this message and exits."
      echo " "
      exit 0
      ;;
    z)
      UTMZone=$OPTARG
      utm_set=1
      proj_set=1
      ;;
    o)
      PolarZone=$OPTARG
      polar_set=1
      proj_set=1
      ;;    
	c)
      CorThr=$OPTARG
      echo "CorThr set to $CorThr"
      ;;
	q)
      SzW=$OPTARG
      echo "SzW set to $SzW"
      ;;
    w)
      echo "Water mask selected: " $OPTARG
	  nameWaterMask=$OPTARG
      ;;
    i)
      echo "ASTER Fit Version: " $OPTARG
	  fitVersion=$OPTARG
      ;;
	n)
	  echo "DEM with uncorrected 3B will be computed"
      NoCorDEM=true
      ;;
	y)
	  echo "Point cloud (.ply) will be exported"
      do_ply=true
      ;;
    a)
	  echo "Orbit angles will be exported"
      do_angle=true
      ;; 
    f)
      ZoomF=$OPTARG
      echo "ZoomF set to $ZoomF"
      ;;
    t)
      RESTERR=$OPTARG
      echo "ResolTerrain set to $RESTERR"
      ;;
    p)
      echo "Purge option (-p) selected."
      run_clean=0
      ;;
    r)
      echo "Re-run scenes (-r) option selected."
      run_again=0
      ;;
    \?)
      echo "RunMicMacAster_batch.sh: Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "RunMicMacAster_NoMatlab.sh: Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ $proj_set -eq 0 ]; then
      echo "Error: Projection has not been set."
      echo "call RunMicMacAster_batch.sh -h for details on usage."
      echo " "
      exit 1
fi

if [ $run_clean -eq 0 ]; then
     echo "Beginning the Purge."
     echo "Hang on, finding zip and met files in sub-folders."
     find . -maxdepth 2 -iname '*.zip*' -exec mv -v {} . \;
     find . -maxdepth 1 -iname 'AST*' -type d | while read d; do
	   echo -ne "Purging directory $d..."\\r
	   rm -rf $d
	   echo "Purging directory $d... Complete."
     done

     # remove ProcessAll.sh
     find -maxdepth 1 -iname 'ProcessAll.sh' -exec rm -v {} \;
     if [ -f Timings.txt ]; then rm -v Timings.txt; fi

     echo "The Purge is now complete."
fi

if [ $run_again -eq 0 ]; then
     echo "No purge this time. Leaving ProcessAll.sh in place."
     echo "Removing Timings.txt"
     if [ -f Timings.txt ]; then rm -v Timings.txt; fi
     echo "Ready to begin processing steps."
fi
# now, we get into the meat of it.
#Make sure we know where we are.
here=$(pwd)


#Sorting the zip and met files into individual folders
if [ $run_again -eq 1 ]; then
	find ./ -maxdepth 1 -name "*.zip" | while read filename; do
	    f=$(basename "$filename")
	    f1=${f%.*}
	    mkdir -p "$f1" "$f1/RawData"
	    unzip $f -d "$f1/RawData"
	    mv "$f" "$f1"
	    echo "start=\$SECONDS" >> ProcessAll.sh
		if [ $utm_set -eq 1 ]; then
			echo "WorkFlowASTER_onescene.sh -c " $CorThr " -q " $SzW " -s " $f1 " -z \""$UTMZone"\" -w " $nameWaterMask " -f " $ZoomF " -t " $RESTERR " -n " $NoCorDEM  " -y " $do_ply " -a " $do_angle " -i " $fitVersion >> ProcessAll.sh
		fi
		if [ $polar_set -eq 1 ]; then
			echo "WorkFlowASTER_onescene.sh -c " $CorThr " -q " $SzW " -s " $f1 " -o \""$PolarZone"\" -w " $nameWaterMask " -f " $ZoomF " -t " $RESTERR " -n " $NoCorDEM  " -y " $do_ply " -a " $do_angle " -i " $fitVersion >> ProcessAll.sh
		fi
	    echo "duration=\$(( SECONDS - start ))" >> ProcessAll.sh
	    echo "echo Procesing of " $f1 " took \" \$duration \" s to process >> Timings.txt" >> ProcessAll.sh
	done  

	echo "Moved and extracted zip files"

	find ./ -maxdepth 1 -name "*.met" | while read filename; do
	    f=$(basename "$filename")
	    f1=${f%.*}
	    f2=${f1%.*}
	    mv "$f" "$f2"
	done  

	echo "Moved met files"
fi

#MicMac processing
echo | bash ProcessAll.sh

# have to pass zone, zoomF to PostProcessMicMac.sh
bash PostProcessMicMac.sh -z "$UTMZone"
