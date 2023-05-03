#!/bin/bash


defineColors() {
	dmsg echo "  Defining colors.."
	gr='\e[0;32m'
	yl='\e[0;33m'
	rd='\e[0;31m'
	bl='\e[0;34m'
	pr='\e[0;35m'
	cy='\e[0;36m'
    blw='\e[0;44;37m'
	ec='\e[m'
}

defineCharrArr() {
	dmsg echo "  Defining char arrays.."
	unset delayChars
	declare -ga delayChars; delayChars=( '[       ]' '[=      ]' '[==     ]' '[===    ]' '[ ===   ]' '[  ===  ]' '[   === ]' '[    ===]' '[     ==]' '[      =]' )
}

graph_6port_1() {
echo -e "
       ┌──────────────────────────────────────────────────┐
       │                                                  │
       │   $gr UUT $ec                                          │
       │                                                  │
       │                                                  │
       │   $rd 1       2       3       4       5       6  $ec   │
       │   ┌──┐    ┌──┐    ┌──┐    ┌──┐    ┌──┐    ┌──┐   │
       └───┼┼┼┼────┼┼┼┼────┼┼┼┼────┼┼┼┼────┼┼┼┼────┼┼┼┼───┘
           ├──┘    ├──┘    ├──┘    ├──┘    └──┘    └──┘
          $yl │ $pr ▲   $yl │ $pr ▲   $yl │ $pr ▲   $yl │ $pr ▲$ec
          $yl │ $pr │   $yl │ $pr │   $yl │ $pr │   $yl │ $pr │$ec
          $yl │ $pr │   $yl │ $pr │   $yl │ $pr │   $yl │ $pr │$ec
          $yl │ $pr │   $yl │ $pr │   $yl │ $pr │   $yl │ $pr │$ec
          $yl │ $pr │   $yl │ $pr │   $yl │ $pr │   $yl │ $pr │$ec
          $yl ▼ $pr │   $yl ▼ $pr │   $yl ▼ $pr │   $yl ▼ $pr │$ec
       ┌───┬──┴────┬──┴────┬──┴────┬──┴───┐
       │ $rd 1$ec│  ▲  $rd 2$ec│  ▲  $rd 3$ec│  ▲  $rd 4$ec│  ▲   │
       │   │  │    │  │    │  │    │  │   │
       │   │  └────┘  │    │  └────┘  │   │
       │   │          │    │          │   │
       │   └──────────┘    └──────────┘   │
       │  $gr MASTER $ec                        │
       │                                  │
       └──────────────────────────────────┘"
}

graph_6port_2() {
echo -e "
      ┌──────────────────────────────────────────────────┐
      │                                                  │
      │   $gr UUT $ec                                          │
      │                                                  │
      │                                                  │
      │   $rd 1       2       3       4       5       6  $ec   │
      │   ┌──┐    ┌──┐    ┌──┐    ┌──┐    ┌──┐    ┌──┐   │
      └───┼┼┼┼────┼┼┼┼────┼┼┼┼────┼┼┼┼────┼┼┼┼────┼┼┼┼───┘
          └──┘    └──┘    └──┘    └──┘    ├──┘    ├──┘
                                        $yl  │ $pr ▲   $yl │ $pr ▲$ec
                        $yl  ┌───────────────┘ $pr │   $yl │ $pr │$ec
                        $yl  │                 $pr │   $yl │ $pr │$ec
                        $yl  │ $pr ┌───────────────┘   $yl │ $pr │$ec
                        $yl  │ $pr │                   $yl │ $pr │$ec
                        $yl  │ $pr │   $yl ┌───────────────┘ $pr │$ec
                        $yl  │ $pr │   $yl │                 $pr │$ec
                        $yl  │ $pr │   $yl │ $pr ┌───────────────┘$ec
                        $yl  ▼ $pr │   $yl ▼ $pr │$ec
      ┌───┬───────┬───────┬──┴────┬──┴───┐
      │ $rd 1$ec│  ▲  $rd 2$ec│  ▲  $rd 3$ec│  ▲  $rd 4$ec│  ▲   │
      │   │  │    │  │    │  │    │  │   │
      │   │  └────┘  │    │  └────┘  │   │
      │   │          │    │          │   │
      │   └──────────┘    └──────────┘   │
      │  $gr MASTER $ec                        │
      │                                  │
      └──────────────────────────────────┘"
}

connWarnMsg() {
	local p1src p1trg p2src p2trg p3src p3trg p4src p4trg p5src p5trg p6src p6trg varArr cnt
	declare varArr=("p1src" "p1trg" "p2src" "p2trg" "p3src" "p3trg" "p4src" "p4trg" "p5src" "p5trg" "p6src" "p6trg")
	let cnt=0
	for arg in "$@"
	do
		if [[ ! $cnt -gt 11 ]]; then
			eval ${varArr[cnt]}=$arg
		else
			warn "${FUNCNAME[0]} received unexpected excessive arg! (arg=$arg)"
		fi
		let cnt+=1
	done	
	dmsg inform "parsed"
	for arg in "${varArr[@]}"
	do
		dmsg echo "$arg = ${!arg}"
	done	

	inform "\tCONNECTION SCHEME\n"
	inform --sil "\t  ------------------------------------------------------"
	inform --sil "\t |     |\t\t\t\t\t  |     |"
	inform --sil "\t |     |\tPort $p1src\t<-------->  Port $p1trg\t  |     |"
	inform --sil "\t |     |\t\t\t\t\t  |     |"
	if [[ ! -z "$p2trg" ]]; then inform --sil "\t |     |\tPort $p2src\t<-------->  Port $p2trg\t  |     |"; else inform --sil "\t |     |\t\t\t\t\t  |     |"; fi
	inform --sil "\t |  S  |\t\t\t\t\t  |     |"
	if [[ ! -z "$p3trg" ]]; then inform --sil "\t |  E  |\tPort $p3src\t<-------->  Port $p3trg\t  |  U  |"; else inform --sil "\t |  E  |\t\t\t\t\t  |  U  |"; fi
	inform --sil "\t |  R  |\t\t\t\t\t  |  U  |"
	if [[ ! -z "$p4trg" ]]; then inform --sil "\t |  V  |\tPort $p4src\t<-------->  Port $p4trg\t  |  T  |"; else inform --sil "\t |  V  |\t\t\t\t\t  |  T  |"; fi
	inform --sil "\t |  E  |\t\t\t\t\t  |     |"
	if [[ ! -z "$p5trg" ]]; then inform --sil "\t |  R  |\tPort $p5src\t<-------->  Port $p5trg\t  |     |"; else inform --sil "\t |  R  |\t\t\t\t\t  |     |"; fi
	inform --sil "\t |     |\t\t\t\t\t  |     |"
	if [[ ! -z "$p6trg" ]]; then inform --sil "\t |     |\tPort $p6src\t<-------->  Port $p6trg\t  |     |"; else inform --sil "\t |     |\t\t\t\t\t  |     |"; fi
	inform --sil "\t |     |\t\t\t\t\t  |     |"
	inform --sil "\t  ------------------------------------------------------"
	inform "\n\tPress enter to continue..\n\n"
	read foo
}

connWarnMsgMgnt() {
	inform "\tCONNECTION SCHEME\n"
	inform --sil "\t  ------------------------------------------------------"
	inform --sil "\t |     |\t\t\t\t\t  |     |"
	inform --sil "\t |     |\tPort 1\t<-------->  MGNT Port\t  |     |"
	inform --sil "\t |     |\t\t\t\t\t  |     |"
	inform --sil "\t |     |\tPort 2\t<-----X  \t\t  |     |"
	inform --sil "\t |  S  |\t\t\t\t\t  |     |"
	inform --sil "\t |  E  |\tPort 3\t<-----X  \t\t  |  U  |"
	inform --sil "\t |  R  |\t\t\t\t\t  |  U  |"
	inform --sil "\t |  V  |\tPort 4\t<-----X  \t\t  |  T  |"
	inform --sil "\t |  E  |\t\t\t\t\t  |     |"
	inform --sil "\t |  R  |\t\t\t\t\t  |     |"
	inform --sil "\t |     |\t\t\t\t\t  |     |"
	inform --sil "\t |     |\t\t\t\t\t  |     |"
	inform --sil "\t |     |\t\t\t\t\t  |     |"
	inform --sil "\t  ------------------------------------------------------"
	inform "\n\tPress enter to continue..\n\n"
	read foo
}

connWarnMsgLoop12() {
	inform "\tCONNECTION SCHEME\n"
	inform --sil "\t  ----------------------------------------------"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t |  U  |\tPort 1\t<-----\                 |"
	inform --sil "\t |  U  |\t\t      |\t\t        |"
	inform --sil "\t |  T  |\tPort 2\t<-----/                 |"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t  ----------------------------------------------"
	inform "\n\tPress enter to continue..\n\n"
	read foo
}

connWarnMsgLoop1324() {
	inform "\tCONNECTION SCHEME\n"
	inform --sil "\t  ----------------------------------------------"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t |     |\tPort 1\t<----------\            |"
	inform --sil "\t |     |\t\t\t   |\t        |"
	inform --sil "\t |     |\tPort 2\t<-----\    |\t        |"
	inform --sil "\t |     |\t\t      |    |\t\t|"
	inform --sil "\t |  U  |\tPort 3\t<-----┼----/  \t        |"
	inform --sil "\t |  U  |\t\t      |\t\t        |"
	inform --sil "\t |  T  |\tPort 4\t<-----/  \t\t|"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t |     |\t\t\t\t        |"
	inform --sil "\t  ----------------------------------------------"
	inform "\n\tPress enter to continue..\n\n"
	read foo
}

untestedPnWarn() {
	critWarn "\t  ------------------------------------------------------ \n" --sil
	critWarn "\t |     |\t    UNTESTED PART-NUMBER\t  |     |\n" --sil
	critWarn "\t |     |\t  MAY NOT WORK AS INTENDED  \t  |     |\n" --sil
	critWarn "\t |     |\t\t\t\t\t  |     |\n" --sil
	critWarn "\t |     |\t    USE AT OWN RISK\t\t  |     |\n" --sil
	critWarn "\t |     |\t\t\t\t\t  |     |\n" --sil
	critWarn "\t  ------------------------------------------------------" --sil
    echo -e "\n"
	critWarn "\tPress enter to continue.."
    echo -e "\n\n"
	read foo
}

animDelay() {
	local frame delayLength msgPrompt totalRuns
	# privateVarAssign "${FUNCNAME[0]}" "delayLength" "$1"; shift
	delayLength=$1; shift
	msgPrompt=$*

	let totalRuns=10
	while [ $totalRuns -gt 0 ]; do
		for frame in "${delayChars[@]}" ; do
			printf "\r%s" "$msgPrompt ${frame}"
			echo -en ""
			sleep "$delayLength"
			let totalRuns--
		done
	done
}


if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tGraphics lib for testing (support: arturd@silicom.co.il)'
	defineColors
	defineCharrArr
else	
	critWarn "This file is only a library and ment to be source'd instead"
	source "${0}"
fi