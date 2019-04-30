#!/usr/bin/env bash

# awsEC2price - A script to query EC2 instance prices

##### Constants



##### Functions

usage()
{
    echo "usage: awsEC2price [-n] [-r aws_region] [-o operating_system] -i instance_type"
    echo "Options:"
    echo "      -n | --nocleanup      # This option allows for the temporary files to be kept for a future session, thus avoiding downloading the price list for every invocation."
    echo "      -r | --region         # AWS Region to query the price for. Default: us-east-1"
    echo "      -o | --os             # Operating system to price for. Possible values: Linux, Windows, SUSE, RHEL. Default value: Linux"
    echo "      -i | --instancetype   # Instance type (e.g. t3-micro) to price for. Mandatory argument."
}

##### Main

while [ "$1" != "" ]; do
  case $1 in
    -r | --region )       shift
                          CAS_AWSREGION=$1
                          ;;
    -i | --instancetype ) shift
                          CAS_INSTANCETYPE=$1
                          ;;
    -o | --os )           shift
                          CAS_INSTANCEOS=$1
                          ;;
    -n | --nocleanup )    CAS_NOCLEANUP=1
                          ;;
    -h | --help )         usage
                          exit
                          ;;
    * )                   usage
                          exit 1
  esac
  shift
done

### Check that mandatory arguments have been provided
if [ "$CAS_INSTANCETYPE" = "" ]; then
  echo "--------------------------------------------"
  echo "ERROR: You need to specify an instance type!"
  echo "--------------------------------------------"
  usage
  exit 1
fi

### Fill in default values for arguments not provided
if [ "$CAS_AWSREGION" = "" ]; then
  CAS_AWSREGION="us-east-1"
fi

if [ "$CAS_INSTANCEOS" = "" ]; then
  CAS_INSTANCEOS="Linux"
fi

### Check to see if we have a temporary file we can leverage and avoid downloading it again
if [ ! -f ./EC2-"$CAS_AWSREGION".json ]; then
  CAS_TEMPDIR="$(mktemp -d)"
  curl 'https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonEC2/current/'"$CAS_AWSREGION"'/index.json' > "$CAS_TEMPDIR"/EC2-"$CAS_AWSREGION".json
  ln -s "$CAS_TEMPDIR"/EC2-"$CAS_AWSREGION".json ./EC2-"$CAS_AWSREGION".json
else
  CAS_TEMPFILE=$(readlink ./EC2-"$CAS_AWSREGION".json)
  CAS_TEMPDIR=$(dirname "${CAS_TEMPFILE}")
fi

### Main query logic
CAS_SKU=$(jq -r '.products[] |
    select (.attributes.instanceType=="'"$CAS_INSTANCETYPE"'") |
    select (.attributes.operatingSystem=="'"$CAS_INSTANCEOS"'") |
    select (.attributes.instancesku==null) |
    select (.attributes.preInstalledSw=="NA") |
    select (.attributes.licenseModel=="No License required") |
    select (.attributes.tenancy=="Shared") |
    .sku' ./EC2-"$CAS_AWSREGION".json)
CAS_PRICE=$(jq -r '.terms.OnDemand[][] |
    select (.sku=="'"$CAS_SKU"'") |
    .priceDimensions[].pricePerUnit.USD' ./EC2-"$CAS_AWSREGION".json)

###### Clean up
if [ "$CAS_NOCLEANUP" != "1" ]; then
  rm ./EC2-"$CAS_AWSREGION".json
  rm $CAS_TEMPDIR/EC2-"$CAS_AWSREGION".json
  rmdir $CAS_TEMPDIR
fi

### Send final result to stdout
echo $CAS_PRICE
