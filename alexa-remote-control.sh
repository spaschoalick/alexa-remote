#!/bin/sh
SET_REFRESH_TOKEN="${REFRESH_TOKEN}"

SET_TTS_LOCALE='pt-BR'

SET_AMAZON='amazon.com'

SET_ALEXA='pitangui.amazon.com'

# cURL binary
SET_CURL='/usr/bin/curl'

# cURL options
#  -k : if your cURL cannot verify CA certificates, you'll have to trust any
#  --compressed : if your cURL was compiled with libz you may use compression
#  --http1.1 : cURL defaults to HTTP/2 on HTTPS connections if available
SET_OPTS='--compressed --http1.1'
#SET_OPTS='-k --compressed --http1.1'

# browser identity
SET_BROWSER='Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:1.0) bash-script/1.0'
#SET_BROWSER='Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:65.0) Gecko/20100101 Firefox/65.0'

# jq binary
SET_JQ='/usr/bin/jq'

# tmp path
SET_TMP="/tmp"

# Volume for speak commands (a SPEAKVOL of 0 leaves the volume settings untouched)
SET_SPEAKVOL="0"
# if no current playing volume can be determined, fall back to normal volume
SET_NORMALVOL="10"

# Device specific volumes (overriding the above)
# SET_DEVICEVOLNAME="EchoDot2ndGen Echo1stGen"
# SET_DEVICEVOLSPEAK="100 30"
# SET_DEVICEVOLNORMAL="100 20"
SET_DEVICEVOLNAME=""
SET_DEVICEVOLSPEAK=""
SET_DEVICEVOLNORMAL=""

# max. age in minutes before volume is read from API (local cache time)
SET_VOLMAXAGE="1"

###########################################
# nothing to configure below here
#

# retrieving environment variables if any are set
REFRESH_TOKEN=${REFRESH_TOKEN:-$SET_REFRESH_TOKEN}
AMAZON=${AMAZON:-$SET_AMAZON}
ALEXA=${ALEXA:-$SET_ALEXA}
BROWSER=${BROWSER:-$SET_BROWSER}
CURL=${CURL:-$SET_CURL}
OPTS=${OPTS:-$SET_OPTS}
TTS_LOCALE=${TTS_LOCALE:-$SET_TTS_LOCALE}
TMP=${TMP:-$SET_TMP}
JQ=${JQ:-$SET_JQ}
SPEAKVOL=${SPEAKVOL:-$SET_SPEAKVOL}
NORMALVOL=${NORMALVOL:-$SET_NORMALVOL}
VOLMAXAGE=${VOLMAXAGE:-$SET_VOLMAXAGE}
DEVICEVOLNAME=${DEVICEVOLNAME:-$SET_DEVICEVOLNAME}
DEVICEVOLSPEAK=${DEVICEVOLSPEAK:-$SET_DEVICEVOLSPEAK}
DEVICEVOLNORMAL=${DEVICEVOLNORMAL:-$SET_DEVICEVOLNORMAL}

COOKIE="${TMP}/.alexa.cookie"
DEVLIST="${TMP}/.alexa.devicelist"
COOKIE_LIFETIME=$(( 24 * 60 * 60 )) # default lifetime of one day before revalidation

GUIVERSION=0

LIST=""
LOGOFF=""
COMMAND=""
TTS=""
UTTERANCE=""
SEQUENCECMD=""
SEQUENCEVAL=""
SEARCHPHRASE=""
PROVIDERID=""
STATIONID=""
CHANNEL=""
QUEUE=""
SONG=""
ALBUM=""
ARTIST=""
TYPE=""
ASIN=""
SEEDID=""
HIST=""
LEMUR=""
CHILD=""
PLIST=""
BLUETOOTH=""
LASTALEXA=""
LASTCOMMAND=""
GETVOL=""
NOTIFICATIONS=""

usage()
{
	echo "$0 [-d <device>|ALL] -e <pause|play|next|prev|fwd|rwd|shuffle|repeat|vol:<0-100>> |"
	echo "          -b [list|<\"AA:BB:CC:DD:EE:FF\">] | -q | -n | -r <\"station name\"|stationId> |"
	echo "          -s <trackID|'Artist' 'Album'> | -t <ASIN> | -u <seedID> | -v <queueID> | -w <playlistId> |"
	echo "          -i | -p | -P | -S | -a | -m <multiroom_device> [device_1 .. device_X] | -lastalexa | -lastcommand | -z | -l | -h"
	echo
	echo "   -e : run command, additional SEQUENCECMDs:"
	echo "        weather,traffic,flashbriefing,goodmorning,singasong,tellstory,"
	echo "        speak:'<text/ssml>',automation:'<routine name>',sound:<soundeffect_name>,"
	echo "        textcommand:'<anything you would otherwise say to Alexa>',"
	echo "        playmusic:<channel e.g. TUNEIN, AMAZON_MUSIC>:'<music name>'"
	echo "   -b : connect/disconnect/list bluetooth device"
	echo "   -c : list 'playmusic' channels"
	echo "   -q : query queue"
	echo "   -n : query notifications"
	echo "   -r : play tunein radio"
	echo "   -s : play library track/library album"
	echo "   -t : play Prime playlist"
	echo "   -u : play Prime station"
	echo "   -v : play Prime historical queue"
	echo "   -w : play library playlist"
	echo "   -i : list imported library tracks"
	echo "   -p : list purchased library tracks"
	echo "   -P : list Prime playlists"
	echo "   -S : list Prime stations"
	echo "   -a : list available devices"
	echo "   -m : delete multiroom and/or create new multiroom containing devices"
	echo "   -lastalexa : print device that received the last voice command"
	echo "   -lastcommand : print last voice command or last voice command of specific device"
	echo "   -z : print current volume level"
	echo "   -login : Logs in, without further command"
	echo "   -l : logoff"
	echo "   -h : help"
}

while [ "$#" -gt 0 ] ; do
	case "$1" in
		--version)
			echo "v0.22"
			exit 0
			;;
		-d)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			DEVICE=$2
			shift
			;;
		-e)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			COMMAND=$2
			shift
			;;
		-b)
			if [ "${2#-}" = "${2}" -a -n "$2" ] ; then
				BLUETOOTH=$2
				shift
			else
				BLUETOOTH="null"
			fi
			;;
		-m)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			LEMUR=$2
			shift
			while [ "${2#-}" = "${2}" -a -n "$2" ] ; do
				CHILD="${CHILD} ${2}"
				shift
			done
			;;
		-r)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			STATIONID=$2
			shift
			# stationIDs are "s1234" or "s12345" 
			if [ -n "${STATIONID##s[0-9][0-9][0-9][0-9]*}" -a -n "${STATIONID##p[0-9][0-9][0-9][0-9]*}" ] ; then
				# search for station name
				STATIONID=$(${CURL} ${OPTS} -s --data-urlencode "query=${STATIONID}" -G "https://api.tunein.com/profiles?fullTextSearch=true" | ${JQ} -r '.Items[] | select(.ContainerType == "Stations") | .Children[] | select( .Index==1 ) | .GuideId')
				if [ -z "$STATIONID" ] ; then
					echo "ERROR: no Station \"$2\" found on TuneIn"
					exit 1
				fi
			fi
			;;
		-s)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			SONG=$2
			shift
			if [ "${2#-}" = "${2}" -a -n "$2" ] ; then
				ALBUM=$2
				ARTIST=$SONG
				shift
			fi
			;;
		-t)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			ASIN=$2
			shift
			;;
		-u)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			SEEDID=$2
			shift
			;;
		-v)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			HIST=$2
			shift
			;;
		-w)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			PLIST=$2
			shift
			;;
		-login)
			LOGIN="true"
			;;
		-l)
			LOGOFF="true"
			;;
		-a)
			LIST="true"
			;;
	    -c)
			CHANNEL="true"
			;;
		-i)
			TYPE="IMPORTED"
			;;
		-p)
			TYPE="PURCHASES"
			;;
		-P)
			PRIME="prime-playlist-browse-nodes"
			;;
		-S)
			PRIME="prime-sections"
			;;
		-q)
			QUEUE="true"
			;;
		-n)
			NOTIFICATIONS="true"
			;;
		-lastalexa)
			LASTALEXA="true"
			;;
		-lastcommand)
			LASTCOMMAND="true"
			;;
		-z)
			GETVOL="true"
			;;
		-h|-\?|--help)
			usage
			exit 0
			;;
		*)
			echo "ERROR: unknown option ${1}"
			usage
			exit 1
			;;
	esac
	shift
done

case "$COMMAND" in
	pause)
			COMMAND='{"type":"PauseCommand"}'
			;;
	play)
			COMMAND='{"type":"PlayCommand"}'
			;;
	next)
			COMMAND='{"type":"NextCommand"}'
			;;
	prev)
			COMMAND='{"type":"PreviousCommand"}'
			;;
	fwd)
			COMMAND='{"type":"ForwardCommand"}'
			;;
	rwd)
			COMMAND='{"type":"RewindCommand"}'
			;;
	shuffle)
			COMMAND='{"type":"ShuffleCommand","shuffle":"true"}'
			;;
	repeat)
			COMMAND='{"type":"RepeatCommand","repeat":true}'
			;;
	vol:*)
			VOL=${COMMAND##*:}
			# volume as integer!
			if [ $VOL -le 100 -a $VOL -ge 0 ] ; then
				SEQUENCECMD='Alexa.DeviceControls.Volume'
				SEQUENCEVAL=',\"value\":\"'${VOL}'\"'
			else
				echo "ERROR: volume should be an integer between 0 and 100"
				usage
				exit 1
			fi
			;;
	textcommand:*)
			SEQUENCECMD='Alexa.TextCommand\",\"skillId\":\"amzn1.ask.1p.tellalexa'
			SEQUENCEVAL=$(echo ${COMMAND##textcommand:} | sed s/\"/\'/g)
			SEQUENCEVAL=',\"text\":\"'${SEQUENCEVAL}'\"'
			;;
	speak:*)
			TTS=$(echo ${COMMAND##speak:} | sed s/\"/\'/g)
			TTS=',\"textToSpeak\":\"'${TTS}'\"'
			SEQUENCECMD='Alexa.Speak'
			SEQUENCEVAL=$TTS
			;;
	sound:*)
			SEQUENCECMD='Alexa.Sound'
			SEQUENCEVAL=',\"soundStringId\":\"'${COMMAND##sound:}'\"'
			;;
	automation:*)
			SEQUENCECMD='automation'
			UTTERANCE=$(echo ${COMMAND##automation:} | sed -r 's/["\\]/ /g')
			;;
	weather)
			SEQUENCECMD='Alexa.Weather.Play'
			;;
	traffic)
			SEQUENCECMD='Alexa.Traffic.Play'
			;;
	flashbriefing)
			SEQUENCECMD='Alexa.FlashBriefing.Play'
			;;
	goodmorning)
			SEQUENCECMD='Alexa.GoodMorning.Play'
			;;
	singasong)
			SEQUENCECMD='Alexa.SingASong.Play'
			;;
	tellstory)
			SEQUENCECMD='Alexa.TellStory.Play'
			;;
	playmusic:*)
			SEQUENCECMD='Alexa.Music.PlaySearchPhrase'
			PROVIDERID=${COMMAND#*:}
			PROVIDERID=${PROVIDERID%:*}
			SEQUENCEVAL=',\"musicProviderId\":\"'${PROVIDERID}'\",'
			SEARCHPHRASE=$(echo ${COMMAND##*:} | sed s/\"/\'/g)
			;;
	"")
			;;
	*)
			echo "ERROR: unknown command \"${COMMAND}\"!"
			usage
			exit 1
			;;
esac

#
# Amazon Login
#
log_in()
{
rm -f ${DEVLIST}.json
rm -f ${COOKIE}
rm -f ${TMP}/.alexa.*.list

if [ -z "${REFRESH_TOKEN}" ] ; then
	echo "Sorry, the very thing this project started with, namely the reverse engineered"
	echo " login to the Amazon web page does no longer work. The Alexa login page has"
	echo " been shut down in favor of a much more modern login process."
	echo
	echo "Please use the device login process https://github.com/adn77/alexa-cookie-cli"
	echo " all you need is the 'refreshToken' looking sth. like 'Atnr|...'"

	exit 1
else
	now=$(date +%s)
	exp=$(( now + COOKIE_LIFETIME ))

	# the date processing ignores the actual cookie validity and simply sets it to "now + COOKIE_LIFETIME"
	${CURL} ${OPTS} -s -X POST --data "app_name=Amazon%20Alexa&requested_token_type=auth_cookies&domain=www.${AMAZON}&source_token_type=refresh_token" --data-urlencode "source_token=${REFRESH_TOKEN}" -H "x-amzn-identity-auth-domain: api.${AMAZON}" https://api.${AMAZON}/ap/exchangetoken/cookies |\
	 ${JQ} -r --arg exp $exp '.response.tokens.cookies | to_entries[] | .key as $domain | .value[] | map_values(if . == true then "TRUE" elif . == false then "FALSE" else . end) | .Expires |= $exp | [(if .HttpOnly=="TRUE" then ("#HttpOnly_" + $domain) else $domain end), "TRUE", .Path, .Secure, .Expires, .Name, .Value] | @tsv' > ${COOKIE}

	if [ -z "$(grep "\.${AMAZON}.*\sat-" ${COOKIE})" ] ; then
		echo "ERROR: cookie retrieval with refresh_token didn't work"
		exit 1
	fi
fi

#
# get CSRF
#
${CURL} ${OPTS} -s -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 https://${ALEXA}/api/language > /dev/null

if [ -z "$(grep "\.${AMAZON}.*\scsrf" ${COOKIE})" ] ; then
	echo "trying to get CSRF from handlebars"
	${CURL} ${OPTS} -s -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 https://${ALEXA}/templates/oobe/d-device-pick.handlebars > /dev/null
fi

if [ -z "$(grep "\.${AMAZON}.*\scsrf" ${COOKIE})" ] ; then
	echo "trying to get CSRF from devices-v2"
	${CURL} ${OPTS} -s -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 https://${ALEXA}/api/devices-v2/device?cached=false > /dev/null
fi

if [ -z "$(grep "\.${AMAZON}.*\scsrf" ${COOKIE})" ] ; then
	echo "ERROR: no CSRF cookie received"
	exit 1
fi
}

#
# get JSON device list
#
get_devlist()
{
	${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})"\
	 "https://${ALEXA}/api/devices-v2/device?cached=false" > ${DEVLIST}.json

	${JQ} -r '.devices[] | "\(.accountName)=\(.deviceType)=\(.serialNumber)=\(.deviceFamily)"' ${DEVLIST}.json > ${DEVLIST}.txt
	${JQ} -r '.devices[] | select( .appDeviceList | length >0 ) as $p | .appDeviceList[] | "\($p.accountName)=\(.deviceType)=\(.serialNumber)=\($p.deviceFamily)"' ${DEVLIST}.json >> ${DEVLIST}.txt
	${JQ} -r '.devices[] | select(.deviceFamily == "WHA") | "\(.accountName)=\(.clusterMembers[])"' ${DEVLIST}.json > ${DEVLIST}_wha.txt
}

check_status()
{
#
# bootstrap with GUI-Version writes GUI version to cookie
#  returns among other the current authentication state
#
	AUTHSTATUS=$(${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L https://${ALEXA}/api/bootstrap?version=${GUIVERSION})
	MEDIAOWNERCUSTOMERID=$(echo $AUTHSTATUS | sed -r 's/^.*"customerId":"([^,]+)",.*$/\1/g')
	AUTHSTATUS=$(echo $AUTHSTATUS | sed -r 's/^.*"authenticated":([^,]+),.*$/\1/g')

	if [ "$AUTHSTATUS" = "true" ] ; then
		return 1
	fi

	return 0
}

#
# set device specific variables from JSON device list
#
set_var()
{
	DEVICE=$(echo ${DEVICE} | sed -r 's/%20/ /g')

	if [ -z "${DEVICE}" ] ; then
		# if no device was supplied, use the first Echo(dot) in device list
		echo -n "setting default device to: "
		DEVICE=$(grep -m 1 -E "ECHO|KNIGHT|ROOK" ${DEVLIST}.txt | cut -d'=' -f1)
		echo ${DEVICE}
	fi

	DEVICESERIALNUMBER=$(grep -m 1 "${DEVICE}" ${DEVLIST}.txt)
	DEVICESERIALNUMBER=${DEVICESERIALNUMBER#*=}

	DEVICEFAMILY=${DEVICESERIALNUMBER##*=}
	DEVICETYPE=${DEVICESERIALNUMBER%%=*}
	DEVICESERIALNUMBER=${DEVICESERIALNUMBER#*=}
	DEVICESERIALNUMBER=${DEVICESERIALNUMBER%=*}

	# customerId is now retrieved from the logged in user
	# the customerId in the device list is always from the user registering the device initially
	# MEDIAOWNERCUSTOMERID=$(${JQ} --arg device "${DEVICE}" -r '.devices[] | select(.accountName == $device) | .deviceOwnerCustomerId' ${DEVLIST}.json)

	if [ -z "${DEVICESERIALNUMBER}" ] ; then
		echo "ERROR: unkown device dev:${DEVICE}"
		exit 1
	fi
}

#
# list available devices from JSON device list
#
list_devices()
{
	${JQ} -r '.devices[].accountName' ${DEVLIST}.json
}

#
# sanitize search phrase
#  ARG1 - sequence command (e.g. Alexa.Music.PlaySearchPhrase)
#  ARG2 - musicProviderID ( TUNEIN, AMASON_MUSIC, CLOUDPLAYER, SPOTIFY, APPLE_MUSIC, DEEZER, I_HEART_RADIO )
#  ARG3 - search phrase
#
sanitize_search()
{
	if [ -n "$1" -a -n "$2" -a -n "$3" ] ; then
		JSON='{"type":"'${1}'","operationPayload":"{\"locale\":\"'${TTS_LOCALE}'\",\"musicProviderId\":\"'${2}'\",\"searchPhrase\":\"'${3}'\"}"}'
	else
		JSON='{"type":"'${SEQUENCECMD}'","operationPayload":"{\"locale\":\"'${TTS_LOCALE}'\",\"musicProviderId\":\"'${PROVIDERID}'\",\"searchPhrase\":\"'${SEARCHPHRASE}'\"}"}'
	fi

	${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "${JSON}" \
	 "https://${ALEXA}/api/behaviors/operation/validate" | ${JQ} -r '.operationPayload.sanitizedSearchPhrase'
}

#
# build node_to_execute string
#  ARG1 - SEQUENCECMD
#  ARG2 - SEQUENCEVAL
#
node()
{
	if [ -n "$1" -a -n "$2" ] ; then
		echo '{\"@type\":\"com.amazon.alexa.behaviors.model.OpaquePayloadOperationNode\",\"type\":\"'${1}'\",\"operationPayload\":{\"deviceType\":\"'${DEVICETYPE}'\",\"deviceSerialNumber\":\"'${DEVICESERIALNUMBER}'\",\"customerId\":\"'${MEDIAOWNERCUSTOMERID}'\",\"locale\":\"'${TTS_LOCALE}'\"'${2}'}}'
	else
		echo '{\"@type\":\"com.amazon.alexa.behaviors.model.OpaquePayloadOperationNode\",\"type\":\"'${SEQUENCECMD}'\",\"operationPayload\":{\"deviceType\":\"'${DEVICETYPE}'\",\"deviceSerialNumber\":\"'${DEVICESERIALNUMBER}'\",\"customerId\":\"'${MEDIAOWNERCUSTOMERID}'\",\"locale\":\"'${TTS_LOCALE}'\"'${SEQUENCEVAL}'}}'
	fi
}

#
# create comma separated string
#
add_node()
{
	if [ -n "$1" ] ; then
		if [ -n "$2" ] ; then
			echo ${1}','${2}
		else
			echo ${1}
		fi
	fi
}

#
# execute command
#
run_cmd()
{
if [ -n "${SEQUENCECMD}" ] ; then
	if [ "${SEQUENCECMD}" = 'automation' ] ; then

		${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
		 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
		 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
		 "https://${ALEXA}/api/behaviors/v2/automations?limit=200" > "${TMP}/.alexa.automation"

		AUTOMATION=$(${JQ} --arg utterance "${UTTERANCE}" -r '.[] | select( .triggers[].payload.utterance == $utterance) | .automationId' "${TMP}/.alexa.automation")
		if [ -z "${AUTOMATION}" ] ; then
			AUTOMATION=$(${JQ} --arg utterance "${UTTERANCE}" -r '.[] | select( .name == $utterance) | .automationId' "${TMP}/.alexa.automation")
			if [ -z "${AUTOMATION}" ] ; then
				echo "ERROR: no such utterance '${UTTERANCE}' in Alexa routines"
				rm -f "${TMP}/.alexa.automation"
				exit 1
			fi
		fi
		SEQUENCE=$(${JQ} --arg automation "${AUTOMATION}" -r -c '.[] | select( .automationId == $automation) | .sequence' "${TMP}/.alexa.automation" | sed 's/"/\\"/g' | sed "s/ALEXA_CURRENT_DEVICE_TYPE/${DEVICETYPE}/g" | sed "s/ALEXA_CURRENT_DSN/${DEVICESERIALNUMBER}/g" | sed "s/ALEXA_CUSTOMER_ID/${MEDIAOWNERCUSTOMERID}/g")
		rm -f "${TMP}/.alexa.automation"

		ALEXACMD='{"behaviorId":"'${AUTOMATION}'","sequenceJson":"'${SEQUENCE}'","status":"ENABLED"}'
	else
		VOLUMEPRENODESTOEXECUTE=''
		VOLUMEPOSTNODESTOEXECUTE=''
		NODESTOEXECUTE=''

		# sanitize search phrase
		if [ -n "${SEARCHPHRASE}" -a -n "${PROVIDERID}" ] ; then
			SEQUENCEVAL=${SEQUENCEVAL}'\"searchPhrase\":\"'${SEARCHPHRASE}'\",\"sanitizedSearchPhrase\":\"'$(sanitize_search)'\"'
		fi

		# iterate over member devices if target is multiroom
		# !!! this is no true multi-room - it just tries to play on every member device in parallel !!!
		if [ "${DEVICEFAMILY}" = "WHA" ] ; then
			MEMBERDEVICESERIALS=$(grep "${DEVICE}" ${DEVLIST}_wha.txt | cut -d'=' -f 2)
			for DEVICESERIALNUMBER in $MEMBERDEVICESERIALS ; do
				DEVICETYPE=$(grep "${DEVICESERIALNUMBER}" ${DEVLIST}.txt | cut -d'=' -f 2)
				NODESTOEXECUTE=$(add_node "$(node)" "${NODESTOEXECUTE}")

				# if SequenceCommand is "Alexa.DeviceControls.Volume" we have to adjust the local volume cache
				if [ "$SEQUENCECMD" = "Alexa.DeviceControls.Volume" ] ; then
					VOL=${SEQUENCEVAL%\\\"}
					VOL=${VOL##*\\\"}
					if [ $VOL -gt 0 ] ; then
						echo $VOL false > "${TMP}/.alexa.volume.${DEVICESERIALNUMBER}"
					else
						echo 0 true > "${TMP}/.alexa.volume.${DEVICESERIALNUMBER}"
					fi
				# add volume setting per device - the WHA volume is unrelyable
				# don't set volume if Alexa.Music.PlaySearchPhrase is used
				elif [ \( $SPEAKVOL -gt 0 -o -n "${DEVICEVOLSPEAK}" \) -a "${SEQUENCECMD}" != "Alexa.Music.PlaySearchPhrase" ] ; then
					DEVICE=$(grep "${DEVICESERIALNUMBER}" ${DEVLIST}.txt | cut -d'=' -f 1)
					get_volumes
					VOLUMEPRENODESTOEXECUTE=$(add_node $(node Alexa.DeviceControls.Volume ',\"value\":\"'${SVOL}'\"') ${VOLUMEPRENODESTOEXECUTE})
					VOLUMEPOSTNODESTOEXECUTE=$(add_node $(node Alexa.DeviceControls.Volume ',\"value\":\"'${VOL}'\"') ${VOLUMEPOSTNODESTOEXECUTE})
				fi
			done

			if [ -z "${NODESTOEXECUTE}" ] ; then
				echo "No clusterMembers found for command: ${COMMAND} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} family:${DEVICEFAMILY}"
				return
			fi
		else
			NODESTOEXECUTE=$(add_node "$(node)" "${NODESTOEXECUTE}")

			if [ "$SEQUENCECMD" = "Alexa.DeviceControls.Volume" ] ; then
				VOL=${SEQUENCEVAL%\\\"}
				VOL=${VOL##*\\\"}
				if [ $VOL -gt 0 ] ; then
					echo $VOL false > "${TMP}/.alexa.volume.${DEVICESERIALNUMBER}"
				else
					echo 0 true > "${TMP}/.alexa.volume.${DEVICESERIALNUMBER}"
				fi
			# don't set volume if Alexa.Music.PlaySearchPhrase is used
			elif [ \( $SPEAKVOL -gt 0 -o -n "${DEVICEVOLSPEAK}" \) -a "${SEQUENCECMD}" != "Alexa.Music.PlaySearchPhrase" ] ; then
				get_volumes
				VOLUMEPRENODESTOEXECUTE=$(add_node $(node Alexa.DeviceControls.Volume ',\"value\":\"'${SVOL}'\"') ${VOLUMEPRENODESTOEXECUTE})
				VOLUMEPOSTNODESTOEXECUTE=$(add_node $(node Alexa.DeviceControls.Volume ',\"value\":\"'${VOL}'\"') ${VOLUMEPOSTNODESTOEXECUTE})
			fi
		fi

		if [ -n "${VOLUMEPRENODESTOEXECUTE}" -a -n "${VOLUMEPOSTNODESTOEXECUTE}" ] ; then
			# execute serially "set_speak_volume" => "sequence_command" => "set_normal_volume"
			#  (each subtask is executed in parallel)
			ALEXACMD='{"behaviorId":"PREVIEW","sequenceJson":"{\"@type\":\"com.amazon.alexa.behaviors.model.Sequence\",\"startNode\":{\"@type\":\"com.amazon.alexa.behaviors.model.SerialNode\",\"nodesToExecute\":[{\"@type\":\"com.amazon.alexa.behaviors.model.ParallelNode\",\"nodesToExecute\":['${VOLUMEPRENODESTOEXECUTE}']},{\"@type\":\"com.amazon.alexa.behaviors.model.ParallelNode\",\"nodesToExecute\":['${NODESTOEXECUTE}']},{\"@type\":\"com.amazon.alexa.behaviors.model.ParallelNode\",\"nodesToExecute\":['${VOLUMEPOSTNODESTOEXECUTE}']}]}}","status":"ENABLED"}'
		else
			# execute in parallel "sequence_command"
			ALEXACMD='{"behaviorId":"PREVIEW","sequenceJson":"{\"@type\":\"com.amazon.alexa.behaviors.model.Sequence\",\"startNode\":{\"@type\":\"com.amazon.alexa.behaviors.model.ParallelNode\",\"nodesToExecute\":['${NODESTOEXECUTE}']}}","status":"ENABLED"}'
		fi
	fi

	# Due to some weird shell-escape-behavior the command has to be written to a file before POSTing it
	echo $ALEXACMD > "${TMP}/.alexa.cmd"

	${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d @"${TMP}/.alexa.cmd" \
	 "https://${ALEXA}/api/behaviors/preview"

	rm -f "${TMP}/.alexa.cmd"
else
	${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d ${COMMAND}\
	 "https://${ALEXA}/api/np/command?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}"
fi
}

#
# play TuneIn radio station
#
play_radio()
{
 JSON='{"contentToken":"music:'$(echo '["music/tuneIn/stationId","'${STATIONID}'"]|{"previousPageId":"TuneIn_SEARCH"}'| base64 -w 0| base64 -w 0 )'"}'

 ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X PUT -d "${JSON}" \
 "https://${ALEXA}/api/entertainment/v1/player/queue?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}"
}

#
# play library track
#
play_song()
{
	if [ -z "${ALBUM}" ] ; then
		JSON="{\"trackId\":\"${SONG}\",\"playQueuePrime\":true}"
	else
		JSON="{\"albumArtistName\":\"${ARTIST}\",\"albumName\":\"${ALBUM}\"}"
	fi

${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "${JSON}"\
 "https://${ALEXA}/api/cloudplayer/queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}&shuffle=false"
}

#
# play library playlist
#
play_playlist()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "{\"playlistId\":\"${PLIST}\",\"playQueuePrime\":true}"\
 "https://${ALEXA}/api/cloudplayer/queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}&shuffle=false"
}

#
# play PRIME playlist
#
play_prime_playlist()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "{\"asin\":\"${ASIN}\"}"\
 "https://${ALEXA}/api/prime/prime-playlist-queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}"
}

#
# play PRIME station
#
play_prime_station()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "{\"seed\":\"{\\\"type\\\":\\\"KEY\\\",\\\"seedId\\\":\\\"${SEEDID}\\\"}\",\"stationName\":\"none\",\"seedType\":\"KEY\"}"\
 "https://${ALEXA}/api/gotham/queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}"
}

#
# play PRIME historical queue
#
play_prime_hist_queue()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "{\"deviceType\":\"${DEVICETYPE}\",\"deviceSerialNumber\":\"${DEVICESERIALNUMBER}\",\"mediaOwnerCustomerId\":\"${MEDIAOWNERCUSTOMERID}\",\"queueId\":\"${HIST}\",\"service\":null,\"trackSource\":\"TRACK\"}"\
 "https://${ALEXA}/api/media/play-historical-queue"
}

#
# show library tracks
#
show_library()
{
	OFFSET="";
	SIZE=50;
	TOTAL=0;
	FILE=${TMP}/.alexa.${TYPE}.list

	if [ ! -f ${FILE} ] ; then
		echo -n '{"playlist":{"entryList":[' > ${FILE}

		while [ 50 -le ${SIZE} ] ; do

${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/cloudplayer/playlists/${TYPE}-V0-OBJECTID?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&size=${SIZE}&offset=${OFFSET}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}" > ${FILE}.tmp

			OFFSET=$(${JQ} -r '.nextResultsToken' ${FILE}.tmp)
			SIZE=$(${JQ} -r '.playlist | .trackCount' ${FILE}.tmp)
			${JQ} -r -c '.playlist | .entryList' ${FILE}.tmp >> ${FILE}
			echo "," >> ${FILE}
			TOTAL=$((TOTAL+SIZE))
		done
		echo "[]],\"trackCount\":\"${TOTAL}\"}}" >> ${FILE}
		rm -f ${FILE}.tmp
	fi
	${JQ} -r '.playlist.trackCount' ${FILE}
	${JQ} '.playlist.entryList[] | .[]' ${FILE}
}

#
# show Prime stations and playlists
#
show_prime()
{
	FILE=${TMP}/.alexa.${PRIME}.list

	if [ ! -f ${FILE} ] ; then
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/prime/{$PRIME}?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}" > ${FILE}

		if [ "$PRIME" = "prime-playlist-browse-nodes" ] ; then
			for I in $(${JQ} -r '.primePlaylistBrowseNodeList[].subNodes[].nodeId' ${FILE} 2>/dev/null) ; do
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/prime/prime-playlists-by-browse-node?browseNodeId=${I}&deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}" >> ${FILE}
			done
		fi
	fi
	${JQ} '.' ${FILE}
}

#
# current queue
#
show_queue()
{
	PARENT=""
	PARENTID=$(${JQ} --arg device "${DEVICE}" -r '.devices[] | select(.accountName == $device) | .parentClusters[0]' ${DEVLIST}.json)
	if [ "$PARENTID" != "null" ] ; then
		PARENTDEVICE=$(${JQ} --arg serial ${PARENTID} -r '.devices[] | select(.serialNumber == $serial) | .deviceType' ${DEVLIST}.json)
		PARENT="&lemurId=${PARENTID}&lemurDeviceType=${PARENTDEVICE}"
	fi

 ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
  -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
  -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
  "https://${ALEXA}/api/np/player?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}${PARENT}" | ${JQ} '.'

 ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
  -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
  -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
  "https://${ALEXA}/api/media/state?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}" | ${JQ} '.'

 ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
  -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
  -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
  "https://${ALEXA}/api/np/queue?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}" | ${JQ} '.'
}

get_music_channels()
{
   ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
    -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
    -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
    "https://${ALEXA}/api/behaviors/entities?skillId=amzn1.ask.1p.music" | ${JQ} -r '.[] | select( .supportedProperties[] == "Alexa.Music.PlaySearchPhrase" ) |  "\(.id) - \(.displayName) \(.description)"'
}

#
# device specific SPEAKVOL/NORMALVOL (sets SVOL/VOL)
#
get_volumes()
{
	VOL=""
	SVOL=""

	# Not using arrays here in order to be compatible with non-Bash
	# Get the list position of the current device type
	IDX=0
	for D in $DEVICEVOLNAME ; do
		if [ "${D}" = "${DEVICE}" ] ; then
			break;
		fi
		IDX=$((IDX+1))
	done

	# get the speak volume at that position
	C=0
	for D in $DEVICEVOLSPEAK ; do
		if [ $C -eq $IDX ] ; then
			if [ -n "${D}" ] ; then SVOL=$D ; fi 
			break
		fi
		C=$((C+1))
	done
	if [ -z "${SVOL}" ] ; then
		SVOL=$SPEAKVOL
	fi

	# try to retrieve the "currently playing" volume
	VOLMAXAGE=1
	VOL=$(get_volume)

	if [ -z "${VOL}" ] ; then
		# get the normal volume of the current device type
		C=0
		for D in $DEVICEVOLNORMAL; do
			if [ $C -eq $IDX ] ; then
				VOL=$D
				break
			fi
			C=$((C+1))
		done
		# if the volume is still undefined, use $NORMALVOL
		if [ -z "${VOL}" ] ; then
			VOL=$NORMALVOL
		fi
	fi

}

#
# current volume level
#
get_volume()
{
	VOLFILE=$(find "${TMP}/.alexa.volume.${DEVICESERIALNUMBER}" -mmin -${VOLMAXAGE} 2>/dev/null)
	if [ -z "${VOLFILE}" ] ; then
		VOL=$(${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
				-H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
				-H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
				"https://${ALEXA}/api/devices/deviceType/dsn/audio/v1/allDeviceVolumes" | ${JQ} -r  --arg device "${DEVICESERIALNUMBER}" '.volumes[] | "\(.dsn) \(.speakerVolume) \(.speakerMuted)"')

		if [ -n "${VOL}" ] ; then
			# write volume and mute state to file
			OIFS=$IFS
			IFS='
'
			set -o noglob
			for LINE in $VOL ; do
				SERIAL=$(echo "${LINE}" | cut -d' ' -f1)
				VOLUME=$(echo "${LINE}" | cut -d' ' -f2)
				MUTED=$(echo "${LINE}" | cut -d' ' -f3)
				echo "${VOLUME} ${MUTED}" > "${TMP}/.alexa.volume.${SERIAL}"
			done
			IFS=$OIFS
			cut -d' ' -f1 "${TMP}/.alexa.volume.${DEVICESERIALNUMBER}"
		fi
	else
		cut -d' ' -f1 "${TMP}/.alexa.volume.${DEVICESERIALNUMBER}"
	fi
}

#
# show notifications and alarms
#
show_notifications()
{
	echo "/api/notifications"
 ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/notifications?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}"
	echo
}

#
# deletes a multiroom device
#
delete_multiroom()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X DELETE \
 "https://${ALEXA}/api/lemur/tail/${DEVICESERIALNUMBER}"
}

#
# creates a multiroom device
#
create_multiroom()
{
	JSON="{\"id\":null,\"name\":\"${LEMUR}\",\"members\":["
	for DEVICE in $CHILD ; do
		set_var
		JSON="${JSON}{\"dsn\":\"${DEVICESERIALNUMBER}\",\"deviceType\":\"${DEVICETYPE}\"},"
	done
	JSON="${JSON%,}]}"

${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "${JSON}" \
 "https://${ALEXA}/api/lemur/tail"
}

#
# list bluetooth devices
#
list_bluetooth()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/bluetooth?cached=false" | ${JQ} --arg serial "${DEVICESERIALNUMBER}" -r '.bluetoothStates[] | select(.deviceSerialNumber == $serial) | "\(.pairedDeviceList[]?.address) \(.pairedDeviceList[]?.friendlyName)"'
}

#
# connect bluetooth device
#
connect_bluetooth()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "{\"bluetoothDeviceAddress\":\"${BLUETOOTH}\"}"\
 "https://${ALEXA}/api/bluetooth/pair-sink/${DEVICETYPE}/${DEVICESERIALNUMBER}"
}

#
# disconnect bluetooth device
#
disconnect_bluetooth()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST \
 "https://${ALEXA}/api/bluetooth/disconnect-sink/${DEVICETYPE}/${DEVICESERIALNUMBER}"
}

#
# get activity CSRF token
#
get_activity_csrf()
{
	${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 	 -H "Content-Type: application/json; charset=UTF-8" \
 	 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET\
	 "https://www.${AMAZON}/alexa-privacy/apd/activity?ref=activityHistory" | grep 'meta name="csrf-token" content="' | sed -r 's/^.*content="([^"]+)".*$/\1/g' > ${TMP}/.alexa.activity.csrf
}

#
# get customer history records
#
get_history()
{
	if ! [ -f ${TMP}/.alexa.activity.csrf ] ; then
		get_activity_csrf
	fi

	RES=$(${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L -w "%{http_code}" \
	 	 -H "Content-Type: application/json; charset=UTF-8" -H "anti-csrftoken-a2z: $(cat ${TMP}/.alexa.activity.csrf)" \
	 	 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d '{"previousRequestToken": null}'\
		 "https://www.${AMAZON}/alexa-privacy/apd/rvh/customer-history-records-v2/?startTime=0&endTime=2147483647000&pageType=VOICE_HISTORY" -o ${TMP}/.alexa.activity.json)

	# try again in case CSRF timed out
	if [ $RES -ne 200 ] ; then
		if [ -z "${try}" ] ; then
			try=1
			rm -f ${TMP}/.alexa.activity.csrf
			get_history
		else
			echo "ERROR: unable to retrieve customer history records"
			exit 1
		fi
	fi
}

#
# device that sent the last command
#
last_alexa()
{
	get_history
	${JQ} -r '.customerHistoryRecords | sort_by(.timestamp) | reverse | .[0] | .recordKey' ${TMP}/.alexa.activity.json | cut -d'#' -f4 | xargs -i grep -m 1 {} ${DEVLIST}.txt
}
#
# last command or last command of a specific device
#
last_command()
{
	get_history

	if [ -z "$DEVICE" ] ; then
		${JQ} -r --arg device "$DEVICE" '.customerHistoryRecords | sort_by(.timestamp) | reverse | .[0] | .voiceHistoryRecordItems | map({key: .recordItemType, value: .transcriptText})' ${TMP}/.alexa.activity.json
	else
		${JQ} -r --arg device "$DEVICE" '[ .customerHistoryRecords | sort_by(.timestamp) | reverse | .[] | select( .device.deviceName == $device) ][0] | .voiceHistoryRecordItems | map({key: .recordItemType, value: .transcriptText})' ${TMP}/.alexa.activity.json
	fi
}

#
# logout
#
log_off()
{
${CURL} ${OPTS} -s -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 https://${ALEXA}/logout > /dev/null

rm -f ${DEVLIST}.json
rm -f ${DEVLIST}.txt
rm -f ${DEVLIST}_wha.txt
rm -f ${COOKIE}
rm -f ${TMP}/.alexa.*.list
rm -f ${TMP}/.alexa.volume.*
}

if [ -z "$LASTALEXA" -a -z "$LASTCOMMAND" -a -z "$CHANNEL" -a -z "$BLUETOOTH" -a -z "$LEMUR" -a -z "$PLIST" -a -z "$HIST" -a -z "$SEEDID" -a -z "$ASIN" -a -z "$PRIME" -a -z "$TYPE" -a -z "$QUEUE" -a -z "$NOTIFICATIONS" -a -z "$LIST" -a -z "$COMMAND" -a -z "$STATIONID" -a -z "$SONG" -a -z "$GETVOL" -a -n "$LOGOFF" ] ; then
	echo "only logout option present, logging off ..."
	log_off
	exit 0
fi

if [ ! -f ${COOKIE} ] ; then
	echo "cookie does not exist. logging in ..."
	log_in
fi

check_status
if [ $? -eq 0 ] ; then
	echo "cookie expired, logging in again ..."
	log_in
	check_status
	if [ $? -eq 0 ] ; then
		echo "log in failed, aborting"
		exit 1
	fi
fi

if [ ! -f ${DEVLIST}.json -o ! -f ${DEVLIST}.txt ] ; then
	echo "device list does not exist. downloading ..."
	get_devlist
	if [ ! -f ${DEVLIST}.json ] ; then
		echo "failed to download device list, aborting"
		exit 1
	fi
fi

if [ -n "$LOGIN" ] ; then
	echo "logged in"
	exit 0
fi

if [ -n "$CHANNEL" ] ; then
	get_music_channels
	exit 0
fi

if [ -n "$COMMAND" -o -n "$QUEUE" -o -n "$NOTIFICATIONS" -o -n "$GETVOL" ] ; then
	if [ "${DEVICE}" = "ALL" ] ; then
		for DEVICE in $( ${JQ} -r '.devices[] | select( ( .deviceFamily == "ECHO" or .deviceFamily == "KNIGHT" or .deviceFamily == "ROOK" or .deviceFamily == "WHA" )  and .online == true ) | .accountName' ${DEVLIST}.json | sed -r 's/ /%20/g') ; do
			set_var
			if [ -n "$COMMAND" ] ; then
				echo "sending cmd:${COMMAND} to dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} customerid:${MEDIAOWNERCUSTOMERID}"
				run_cmd
				# in order to prevent a "Rate exceeded" we need to delay the command
				sleep 1
				echo
			elif [ -n "$GETVOL" ] ; then
				echo "get volume for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
				get_volume
			elif [ -n "$NOTIFICATIONS" ] ; then
				echo "notifications info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
				show_notifications
			else
				echo "queue info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
				show_queue
				echo
			fi
		done
	else
		set_var
		if [ -n "$COMMAND" ] ; then
			echo "sending cmd:${COMMAND} to dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} customerid:${MEDIAOWNERCUSTOMERID}"
			run_cmd
			echo
		elif [ -n "$GETVOL" ] ; then
			echo "get volume for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
			get_volume
		elif [ -n "$NOTIFICATIONS" ] ; then
			echo "notifications info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
			show_notifications
		else
			echo "queue info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
			show_queue
			echo
		fi
	fi
elif [ -n "$LEMUR" ] ; then
	DEVICESERIALNUMBER=$(${JQ} --arg device "${LEMUR}" -r '.devices[] | select(.accountName == $device and .deviceFamily == "WHA") | .serialNumber' ${DEVLIST}.json)
	if [ -n "$DEVICESERIALNUMBER" ] ; then
		delete_multiroom
	else
		if [ -z "$CHILD" ] ; then
			echo "ERROR: ${LEMUR} is no multiroom device. Cannot delete ${LEMUR}".
			exit 1
		fi
	fi
	if [ -z "$CHILD" ] ; then
		echo "Deleted multi room dev:${LEMUR} serial:${DEVICESERIALNUMBER}"
	else
		echo "Creating multi room dev:${LEMUR} member_dev(s):${CHILD}"
		create_multiroom
		echo
	fi
	rm -f ${DEVLIST}.json
	rm -f ${DEVLIST}.txt
	rm -f ${DEVLIST}_wha.txt
	get_devlist
elif [ -n "$BLUETOOTH" ] ; then
	if [ "$BLUETOOTH" = "list" -o "$BLUETOOTH" = "List" -o "$BLUETOOTH" = "LIST" ] ; then
		if [ "${DEVICE}" = "ALL" ] ; then
			for DEVICE in $(${JQ} -r '.devices[] | select( .deviceFamily == "ECHO" or .deviceFamily == "KNIGHT" or .deviceFamily == "ROOK" or .deviceFamily == "WHA") | .accountName' ${DEVLIST}.json | sed -r 's/ /%20/g') ; do
				set_var
				echo "bluetooth devices for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}:"
				list_bluetooth
				echo
			done
		else
			set_var
			echo "bluetooth devices for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}:"
			list_bluetooth
			echo
		fi
	elif [ "$BLUETOOTH" = "null" ] ; then
		set_var
		echo "disconnecting dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} from bluetooth"
		disconnect_bluetooth
		echo
	else
		set_var
		echo "connecting dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} to bluetooth device:${BLUETOOTH}"
		connect_bluetooth
		echo
	fi
elif [ -n "$STATIONID" ] ; then
	set_var
	echo "playing stationID:${STATIONID} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
	play_radio
elif [ -n "$SONG" ] ; then
	set_var
	echo "playing library track:${SONG} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
	play_song
elif [ -n "$PLIST" ] ; then
	set_var
	echo "playing library playlist:${PLIST} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
	play_playlist
elif [ -n "$LIST" ] ; then
	echo "the following devices exist in your account:"
	list_devices
elif [ -n "$TYPE" ] ; then
	set_var
	echo -n "the following songs exist in your ${TYPE} library: "
	show_library
elif [ -n "$PRIME" ] ; then
	set_var
	echo "the following songs exist in your PRIME ${PRIME}:"
	show_prime
elif [ -n "$ASIN" ] ; then
	set_var
	echo "playing PRIME playlist ${ASIN}"
	play_prime_playlist
elif [ -n "$SEEDID" ] ; then
	set_var
	echo "playing PRIME station ${SEEDID}"
	play_prime_station
elif [ -n "$HIST" ] ; then
	set_var
	echo "playing PRIME historical queue ${HIST}"
	play_prime_hist_queue
elif [ -n "$LASTALEXA" ] ; then
	last_alexa
elif [ -n "$LASTCOMMAND" ] ; then
	last_command
else
	echo "no alexa command received"
fi

if [ -n "$LOGOFF" ] ; then
	echo "logout option present, logging off ..."
	log_off
fi
