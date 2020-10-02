; SCHOOL DYNAMICS OF COVID-19 IN LAVRAS
; PROGRAMMER: ERIC ARAUJO
; LAST UPDATE: 2020-10-01

extensions [csv nw]

globals [
  sectors-list               ; list containing all (demographic) sectors used for the simulation
  #-icus-available           ; ICUs available
  #-icus-total               ; ICUs existant
  deaths-virus               ; deaths caused by complications from the infection
  deaths-infra               ; deaths caused by the lack of ICUs available
  ; statistics to be loaded
  contacts-daily              ; number of contacts per day
  contagion-prob-daily       ; daily probability for transmission of the infection according to the viral charge

  weekday-effect             ; effect on the number of contacts during the week
  initial-infected
]

breed [classes class]
classes-own [
  class-id
  initial-time
  duration
  #-students
  #-teachers
  school-id
  sector-id
  age-avg-students
  age-std-students
  age-avg-teachers
  age-std-teachers
]


breed [people person]

people-own [
  student?
  teacher?
  school-member-id     ;
  age
  gender
  classes-list         ; list of classes the student/teacher participate
  house-id             ; id of the house where the agent lives
  sector-id            ; (demographic) sector where the person lives

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  infected?         ; not infected or infected?
  symptoms?         ; presenting symptoms
  immune?           ; recovered and immune
  hospitalized?     ; in hospital bed
  susceptible?   ; never infected
  icu?              ; admitted in the ICU
  dead?             ; died
  severity          ; level of severity 0 (Asymptomatic) 1 (Mild) 2 (Severe) 3 (Critical)

  days-infected     ; progression of the infection in days
  #-transmitted     ; number of people to whom the infection was transmitted by the person

  ;;; INTERACTIONS
  contacts-household      ; contacts @ home (50%)
  contacts-school         ; contacts @ school (45%)
  contacts-random         ; random contacts (5%)
  contacts-total          ; total contacts
  contacts-infected       ; percentage of contacts when person is infected
  prob-spread             ; probability of spread of the disease
  household-effect        ; household size effect on number of contacts per day
  ;;; interventions
  isolated?         ; agent in quarentine
  id-number         ; for using 'rodízio'. The id number is the last number of the CPF of the person
]


undirected-link-breed [ relatives relative ]
undirected-link-breed [ colleagues colleague ]


to setup
  ifelse load-world? [ load-setup ] [ initial-setup ]
end

to initial-setup
  clear-all
  if debug? [ show "Debug is on! Initiating setup from beginning!\n" ]

  load-statistics
  setup-globals
  generate-classes
  ;generate-people "../data/IBGE_LAVRAS/age_men_urban.csv" "male" ; original folder
  ;generate-people "../data/IBGE_LAVRAS/age_women_urban.csv" "female" ; original folder
  ;attribute-households "../data/IBGE_LAVRAS/households_urban.csv" ; original folder
  generate-people "./inputs/age_men_urban.csv" "male"
  generate-people "./inputs/age_women_urban.csv" "female"
  attribute-households "./inputs/households_urban.csv"
  select-teachers
  select-students
  setup-connections
  type "Setup <before> " type random 100 type "\n"
  export-world "scenario.csv"
  type "Setup <after> " type random 100 type "\n"
  type "Setup <after2> " type random 100 type "\n\n"
  initial-infection
  reset-ticks
end

to load-setup
  if debug? [ show "Debug is on! Initiating loading setup from file scenario.csv!\n" ]
  clear-all
  type "Load Setup <before>" type random 100

  import-world "scenario.csv"

  random-seed new-seed

  type "\nLoad Setup <after> " type random 100 type "\n"
  type "Load Setup <after 2> " type random 100 type "\n\n"
  setup-globals
  initial-infection
  reset-ticks
  if debug? [ show "Load complete!\n" ]
end


;;;; STATISTICS OF NUMBER OF CONTACTS AND CONTAGION PROBABILITY
to load-statistics
  let file1 "./inputs/infection/contacts_daily.csv"
  let file2 "./inputs/infection/contagion_chance.csv"
  set contacts-daily read-csv-to-list file1
  set contagion-prob-daily read-csv-to-list file2
  if debug? [show "Loaded statistics for the daily contacts and contagion probabilities. (1/9)\n"]
end


to setup-globals
  set sectors-list []
  set #-icus-available 12
  set #-icus-total 12
  set deaths-virus 0
  set deaths-infra 0
  set initial-infected 10

  if debug? [show "Global variables initiated. (2/9)\n"]
end

to generate-classes
  file-close-all
  ; file-open "../data/INEP_LAVRAS/classes.csv" ; original folder
  file-open "./inputs/classes.csv"

  ;; To skip the header row in the while loop,
  ;  read the header row here to move the cursor
  ;  down to the next line.
  ; ID_TURMA TX_HR_INICIAL NU_DURACAO_TURMA QT_MATRICULAS TP_ETAPA_ENSINO NU_DIAS_ATIVIDADE CO_ENTIDADE CD_GEOCODI AGE_AVG_STUDENTS AGE_STD_STUDENTS NUM_TEACHERS AGE_AVG_TEACHERS AGE_STD_TEACHERS
  let headings csv:from-row file-read-line

  while [ not file-at-end? ] [
    let data csv:from-row file-read-line
    if debug? [print data]
    create-classes 1 [
      set class-id item 1 data
      set initial-time item 2 data
      set duration item 3 data
      set #-students item 4 data

      set school-id item 7 data

      set sector-id item 8 data

      set age-avg-students item 9 data
      set age-std-students item 10 data

      set #-teachers item 11 data
      set age-avg-teachers item 12 data
      set age-std-teachers item 13 data

      set hidden? true
    ]
  ]
  file-close-all
  if debug? [show "Classes generated. (3/9)\n"]
end

to generate-people [file-data sex]
  file-close-all
  file-open file-data
  let headings file-read-line
  let indexes split2 headings ","

  while [not file-at-end?]
  [
    let line file-read-line
    let data split2 line ","
    let sid read-from-string item 1 data
    if not member? sid sectors-list [set sectors-list fput sid sectors-list]
    ; there are 101 columns for the years from 0 to 100
    foreach (n-values 101 [i -> i])[ x ->
      ; create men
      create-people read-from-string item (x + 2) data [
        set age x
        set sector-id sid
        set gender sex
        set student? false
        set teacher? false
        set classes-list []
        set house-id -1 ; initiate null

        ;;;;;;;;;;;;;;;;;;;;;;;;;
        set infected? false
        set symptoms? false
        set immune? false
        set hospitalized? false
        set icu? false
        set dead? false
        set susceptible? true
        set #-transmitted 0
        set isolated? false
        set id-number random 10

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ifelse age <= 4 [ set contacts-total round (random-normal 10.21 7.65) ]
        [
          ifelse age <= 9 [ set contacts-total round (random-normal 14.81 10.09) ]
          [
            ifelse age <= 14 [ set contacts-total round (random-normal 18.22 12.27) ]
            [
              ifelse age <= 19 [ set contacts-total round (random-normal 17.58 12.03) ]
              [
                ifelse age <= 29 [ set contacts-total round (random-normal 13.57 10.06) ]
                [
                  ifelse age <= 39 [ set contacts-total round (random-normal 14.14 10.15) ]
                  [
                    ifelse age <= 49 [ set contacts-total round (random-normal 13.83 10.86) ]
                    [
                      ifelse age <= 59 [ set contacts-total round (random-normal 12.3 10.23) ]
                      [
                        ifelse age <= 69 [ set contacts-total round (random-normal 9.21 7.96) ]
                        [
                          set contacts-total round (random-normal 6.89 5.83)
                        ] ; 69
                      ]
                    ] ; 49
                  ]
                ]
              ]
            ] ; age <=14
          ] ; age <= 9
        ] ; age <=4
      ]
    ]
  ] ;end of while
  file-close-all
  if debug? [ifelse sex = "male" [show (word sex " people generated. (4/9)\n")][show (word sex " people generated. (5/9)\n")]
  ]
end

to attribute-households [file-data ]
  file-close-all
  file-open file-data
  let headings file-read-line
  ; ["" "Cod_setor" "households" "population"]
  let indexes split2 headings ","

  while [ not file-at-end? ] [
    let line file-read-line
    let data split2 line ","
    ;show data

    let sid read-from-string item 1 data
    let households item 2 data

    ; fill the houses
    ask people with [sector-id = sid and house-id = -1 ][
      set house-id random read-from-string households ; random uniform distribution
    ]
  ] ; end of while
  file-close-all
  if debug? [show "Households attributed to people. (6/9)\n"]
end

to select-teachers
  file-close-all
  ;  file-open "../data/INEP_LAVRAS/teachers.csv" ; original folder
  file-open "./inputs/teachers.csv"

  ;; To skip the header row in the while loop,
  ;  read the header row here to move the cursor
  ;  down to the next line.
  ; ID_TURMA TX_HR_INICIAL NU_DURACAO_TURMA QT_MATRICULAS TP_ETAPA_ENSINO NU_DIAS_ATIVIDADE CO_ENTIDADE CD_GEOCODI AGE_AVG_STUDENTS AGE_STD_STUDENTS NUM_TEACHERS AGE_AVG_TEACHERS AGE_STD_TEACHERS

  let headings file-read-line

  while [not file-at-end?]
  [
    let line file-read-line
    let data split2 line ","

    let person-id item 1 data
    let cid read-from-string item 4 data

    ifelse any? people with [school-member-id = person-id] [; if the teacher exists already
      ask one-of people with [school-member-id = person-id][
        set classes-list fput cid classes-list
      ]
    ][ ; teacher does not exist
      let age-requested read-from-string item 2 data
      if age-requested < 0 [set age-requested 0]
      if age-requested > 100 [set age-requested 100]
      let gender-requested ifelse-value (item 3 data) = "1" ["male"]["female"]
      ask one-of people with [age = age-requested and student? = false and teacher? = false and gender = gender-requested ] [
        set teacher? true
        set student? false

        set school-member-id item 1 data
        set classes-list fput cid classes-list
        set hidden? true
      ]
    ] ; end of ifelse
  ] ;end of while
  file-close-all
  if debug? [show "Teachers selected. (7/9)\n"]
end

to select-students
  ask classes [
    ; create students
    let vacancies #-students
    let age-required round (random-normal age-avg-students age-std-students)
    if age-required < 0 [set age-required 0]
    if age-required > 100 [set age-required 100]

    let cid class-id
    let sid sector-id

    loop [
      ; while there are students from that sector and vacancies...
      while [any? people with [age = age-required and sector-id = sid and student? = false and teacher? = false] and vacancies > 0]
        [
          ask one-of people with [age = age-required and sector-id = sid and student? = false and teacher? = false]
            [
              set student? true
              set classes-list fput cid classes-list
            ] ; set one student

          set vacancies vacancies - 1
          set age-required round (random-normal age-avg-students age-std-students)
          if age-required < 0 [set age-required 0]
          if age-required > 100 [set age-required 100]
      ] ; end of while

      ; stop in case vacancies are over
      if vacancies = 0 [stop]

      ; if there are no more students from that area, search in other areas
      while [any? people with [age = age-required and student? = false and teacher? = false] and vacancies > 0]
        [
          ask one-of people with [age = age-required and student? = false and teacher? = false]
            [
              set student? true
              set classes-list fput cid classes-list
            ] ; set one student
          set vacancies vacancies - 1
          set age-required round (random-normal age-avg-students age-std-students)
          if age-required < 0 [set age-required 0]
          if age-required > 100 [set age-required 100]
      ] ; end of while

      ; stop in case vacancies are over
      if vacancies = 0 [stop]

      ; relax requirements
      while [any? people with [age > age-required - 5 and age < age-required + 5 and student? = false and teacher? = false] and vacancies > 0]
        [
          ask one-of people with [age > age-required - 5 and age < age-required + 5 and student? = false and teacher? = false]
            [
              set student? true
              set classes-list fput cid classes-list
            ] ; set one student
          set vacancies vacancies - 1
          set age-required round (random-normal age-avg-students age-std-students)
          if age-required < 0 [set age-required 0]
          if age-required > 100 [set age-required 100]
      ] ; end of while

      if vacancies > 0 [print "deu pau"]

    ] ; end of loop
  ] ; end of ask classes
  if debug? [show "Students selected. (8/9)\n"]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CONNECTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-connections
  set-connections-schools
  set-connections-families
  if debug? [show "Connections stabilished. (9/9)\n"]
end

to set-connections-schools
  if debug? [show "Start creating schools ties (9a/9)\n"]
  let counter 0
  ; Create network of schools
  ask people with [not empty? classes-list] [
    foreach classes-list [ x ->
      create-colleagues-with other people with [ member? x classes-list ]
    ]
    set counter counter + 1
    if debug? [if counter mod 1000 = 0 [show counter]]
  ]
  if debug? [show "End of connecting schools (9a/9)\n"]
end

to set-connections-families

  if debug? [show "Start creating family ties (9b/9)\n"]
  let counter 0
  foreach sectors-list [ sec ->
    let peopleset people with [sector-id = sec]
    ask peopleset [
      create-relatives-with other peopleset with [house-id = [house-id] of myself]
    ]
    set counter counter + 1
    if debug? [if counter mod 20 = 0 [show (word "Sectors: " counter "\n")]]
  ]
  if debug? [show "End of connecting families (9b/9)\n"]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GO ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go
  ;if ticks = 120 [stop]

  if count people with [infected? or hospitalized? or icu?] = 0 [stop]

  if debug? [type count people with [infected?] type " " type count people with [hospitalized?] type " " type count people with [icu?] type "\n"]

  disease-development

  ifelse ticks mod 7 = 0 [ set weekday-effect 0.6 ][
    ifelse ticks mod 7 = 6 [set weekday-effect 0.8 ][ set weekday-effect 1 ]
  ]

  if self-isolation? [ isolate-perc ]

  interact-with-others
  ;;if quarentine-mode?[set-quarentine] ; define if it is quarentine time or not

  tick
end




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;; INFECTION PROGRESS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to disease-development
  ask people with [infected? and not dead?] [
    ; increment day
    set days-infected days-infected + 1
    ; update information from the cases
    set contacts-infected item days-infected (item severity contacts-daily) ; get the number of contacts based on the severity of the person and the days of infection
    set prob-spread (item days-infected (item severity contagion-prob-daily)) * 2 ;;;;;; XXXXXXXX

    if severity = 0 [
      if days-infected = 27 [
        set infected? false
        set immune? true
      ]
    ] ; end severity = 0 or 1

    if severity = 1[
      if days-infected = 6 [ set symptoms? true ]
      if days-infected = 11 [ set symptoms? false ]
      if days-infected = 27 [
        set infected? false
        set immune? true
      ]
    ] ; end severity = 0 or 1

    if severity = 2 [
      if days-infected = 6 [ set symptoms? true ]
      if days-infected = 11 [ set hospitalized? true ]
      if days-infected = 19 [ set hospitalized? false ]
      if days-infected = 27 [
        set infected? false
        set symptoms? false
        set hospitalized? false
        set immune? true
      ]
    ] ; end severity = 2

    if severity = 3 [
      if days-infected = 6 [ set symptoms? true ]
      if days-infected = 11 [ set hospitalized? true ]
      if days-infected = 17 [ icu self]
      if days-infected = 27 [
        set symptoms? false
        set icu? false
        set infected? false
        ; free icus
        set #-icus-available #-icus-available + 1

        ; chance of death
        ifelse random-float 100 < 50 [ ; 50% of chance to die
          ; die
          set dead? true
          ask my-links [die]
          set deaths-virus deaths-virus + 1 ; deaths because of the virus
        ][
          set immune? true
        ]
      ]
    ] ; end severity = 3

  ]
end




to icu [ citizen ]
  ask citizen [
    set hospitalized? false

    ifelse #-icus-available > 0 [
      set icu? true
      set #-icus-available #-icus-available - 1
    ][
      ; die
      set icu? false
      set infected? false
      set symptoms? false
      set dead? true
      ask my-links [die]
      set deaths-infra deaths-infra + 1 ; deaths because of lack of infrastructure
    ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; INTERACTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to interact-with-others
  ; only infected turtles matter for the spread of the virus
  ask people with [infected? and not dead? and prob-spread > 0] [

    ; calculate home contacts and school contacts according to day of week and household size.

    let household-size count my-relatives
    let contagion-probability prob-spread

    ifelse household-size < 6 [ set household-effect item household-size [1 1.17 1.2 1.36 1.46 1.56] ][ set household-effect 1.56 ]
    ; weekday-effect is global

    let sTurtle self

    ; 50% home 45% school 5% random

    set contacts-household round (contacts-total * contacts-infected * household-effect * weekday-effect * 0.50)

    ifelse student? or teacher? [
      ; schools are open and it is NOT weekend
      ifelse schools? and (ticks mod 7 != 0) and (ticks mod 7 != 6) [
        set contacts-school round (contacts-total * contacts-infected * household-effect * weekday-effect * 0.45)
        set contacts-random round (contacts-total * contacts-infected * household-effect * weekday-effect * 0.05)
      ][
        set contacts-school 0
        set contacts-random round (contacts-total * contacts-infected * household-effect * weekday-effect * 0.50)
      ]
    ][
      ; non school people
      set contacts-school 0
      set contacts-random round (contacts-total * contacts-infected * household-effect * weekday-effect * 0.50)
    ]

    if count relative-neighbors = 0 [
      set contacts-random contacts-random + contacts-household
      set contacts-household 0
    ]

    ; person in self-isolation
    if isolated? [
      set contacts-school 0
      set contacts-random 0
    ]


    repeat contacts-household [
      ask one-of relative-neighbors [
        if susceptible? and not isolated? [
          if random-float 100 <= contagion-probability [
            ;if debug? [type sTurtle type " infected " type self type "\n"]
            infect self
            ask sTurtle [set #-transmitted #-transmitted + 1]  ; increment the number of transmitted
          ] ; end of if contagion
        ] ; end of if never-infected
      ] ; end of ask one-of
    ] ; end of repeat

    repeat contacts-school [
      ask one-of colleague-neighbors [
        if susceptible? and not isolated? [
          if random-float 100 <= contagion-probability [
            ;if debug? [type sTurtle type " infected " type self type "\n"]
            infect self
            ask sTurtle [set #-transmitted #-transmitted + 1]  ; increment the number of transmitted
          ] ; end of if contagion
        ] ; end of if never-infected
      ] ; end of ask one-of
    ] ; end of repeat

    repeat contacts-random [
      ask one-of people [
        if susceptible? and not isolated? [
          if random-float 100 <= contagion-probability [
            ;if debug? [type sTurtle type " infected " type self type "\n"]
            infect self
            ask sTurtle [set #-transmitted #-transmitted + 1]  ; increment the number of transmitted
          ] ; end of if contagion
        ] ; end of if never-infected
      ] ; end of ask one-of
    ] ; end of repeat

  ] ; end of the whole process
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; INFECTION ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to initial-infection
   infect n-of initial-infected people
end

;;;; INFECT PROCEDURES
to infect [ agent ]
  ask agent [
    set infected? true
    set susceptible? false
    set immune? false
    set days-infected 0

    ;; define severity
    let chance random 100

    ifelse age > 60 [ ;old
      ifelse chance < 20 [ set severity 0 ][
        ifelse chance < 40 [ set severity 1 ][
          ifelse chance < 60 [ set severity 2 ] [ set severity 3 ]
        ]
      ]
    ] [ ; young
      ifelse chance < 60 [ set severity 0 ][
        ifelse chance < 80 [ set severity 1 ][
          ifelse chance < 98 [ set severity 2 ][ set severity 3 ]
        ]
      ]
    ]
    set contacts-infected item days-infected (item severity contacts-daily) ; get the number of contacts based on the severity of the person and the days of infection
    set prob-spread item days-infected (item severity contagion-prob-daily)
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; QUARANTINE FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to isolate-perc
  let perc-pop count people with [not dead?] * perc-isolated / 100
  ; reset isolated? variable
  ask people with [isolated?][ set isolated? false ]
  ; ask the perc of people to go on isolation
  ifelse schools? [
    ask n-of perc-pop people with [ not teacher? and not student? and not hospitalized? and not icu? and not dead? ] [ set isolated? true ]
  ][
    ask n-of perc-pop people with [ not hospitalized? and not icu? and not dead? ] [ set isolated? true ]
  ]
end




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; AUXILIAR FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report split2 [ string delim ]
  ; https://stackoverflow.com/questions/51128744/trouble-with-advanced-netlogo-code-involving-a-question-mark
  ; split the string up into individual characters
  let characters fput [""] n-values ( length string ) [ a -> substring string a ( a + 1 ) ]

  ;  build words, cutting where the delimiter occurs
  let output reduce [ [ b c ] ->
    ifelse-value ( c = delim )
    [ lput "" b ]
    [ lput word last b c but-last b ]
  ] characters

  report output
end

to-report read-csv-to-list [ file ]
  file-open file
  let returnList []
  while [ not file-at-end? ] [
    let row (csv:from-row file-read-line ",")
    set returnList lput row returnList
  ]
  if debug? [  show returnList ]
  file-close
  report returnList
end


to statistics
  print ( word "Average number of colleagues per student: " mean [count my-colleagues] of people with [student?] "\n")
  print ( word "Average number of colleagues per teacher: " mean [count my-colleagues] of people with [teacher?] )
end
@#$#@#$#@
GRAPHICS-WINDOW
749
18
930
200
-1
-1
5.242424242424242
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

SWITCH
111
326
251
359
debug?
debug?
1
1
-1000

MONITOR
605
22
722
67
# of Classes
count classes
17
1
11

MONITOR
607
73
723
118
Total # of People
count people
17
1
11

MONITOR
611
237
726
282
# of Teachers
count people with [teacher?]
17
1
11

MONITOR
611
288
726
333
# of Students
count people with [student?]
17
1
11

BUTTON
24
13
90
46
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
605
126
721
171
Total # Men
count people with [gender = \"male\"]
17
1
11

MONITOR
604
178
721
223
Total # Women
count people with [gender = \"female\" ]
17
1
11

BUTTON
337
229
404
262
Import
import-world \"scenario.csv\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
18
59
92
104
Infected
count people with [infected?]
17
1
11

MONITOR
18
160
97
205
Hospitalized
count people with [hospitalized?]
17
1
11

MONITOR
16
210
99
255
ICU
count people with [icu?]
17
1
11

BUTTON
228
15
291
48
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
18
109
96
154
Symptoms
count people with [symptoms?]
17
1
11

MONITOR
16
263
96
308
Dead
count people with [dead?]
17
1
11

SWITCH
109
279
251
312
schools?
schools?
0
1
-1000

SLIDER
406
73
578
106
perc-isolated
perc-isolated
0
100
50.0
10
1
%
HORIZONTAL

SWITCH
109
234
253
267
self-isolation?
self-isolation?
0
1
-1000

MONITOR
17
315
94
360
Isolated
count people with [isolated?]
17
1
11

SWITCH
115
63
246
96
load-world?
load-world?
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="self-isolation-off" repetitions="10" runMetricsEveryStep="true">
    <setup>load-setup</setup>
    <go>go</go>
    <metric>count people with [infected?]</metric>
    <metric>count people with [susceptible?]</metric>
    <metric>count people with [symptoms?]</metric>
    <metric>count people with [hospitalized?]</metric>
    <metric>count people with [icu?]</metric>
    <metric>count people with [isolated?]</metric>
    <metric>count people with [immune?]</metric>
    <metric>count people with [dead? and teacher?]</metric>
    <metric>count people with [dead? and student?]</metric>
    <metric>count people with [dead? and age &gt;= 60]</metric>
    <metric>count people with [dead? and age &gt;= 60 and teacher?]</metric>
    <metric>count people with [dead? and age &lt; 60 and teacher?]</metric>
    <metric>count people with [isolated? and age &gt;= 60]</metric>
    <metric>deaths-virus</metric>
    <metric>deaths-infra</metric>
    <metric>sum [#-transmitted] of people with [not susceptible?]/ count people with [not susceptible?]</metric>
    <enumeratedValueSet variable="self-isolation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="perc-isolated">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="self-isolation-on" repetitions="10" runMetricsEveryStep="true">
    <setup>load-setup</setup>
    <go>go</go>
    <metric>count people with [infected?]</metric>
    <metric>count people with [susceptible?]</metric>
    <metric>count people with [symptoms?]</metric>
    <metric>count people with [hospitalized?]</metric>
    <metric>count people with [icu?]</metric>
    <metric>count people with [isolated?]</metric>
    <metric>count people with [immune?]</metric>
    <metric>count people with [dead? and teacher?]</metric>
    <metric>count people with [dead? and student?]</metric>
    <metric>count people with [dead? and age &gt;= 60]</metric>
    <metric>count people with [dead? and age &gt;= 60 and teacher?]</metric>
    <metric>count people with [dead? and age &lt; 60 and teacher?]</metric>
    <metric>count people with [isolated? and age &gt;= 60]</metric>
    <metric>deaths-virus</metric>
    <metric>deaths-infra</metric>
    <metric>sum [#-transmitted] of people with [not susceptible?]/ count people with [not susceptible?]</metric>
    <enumeratedValueSet variable="self-isolation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="perc-isolated">
      <value value="25"/>
      <value value="50"/>
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test1" repetitions="1" runMetricsEveryStep="true">
    <setup>load-setup</setup>
    <go>go</go>
    <metric>count people with [infected?]</metric>
    <metric>count people with [susceptible?]</metric>
    <metric>count people with [symptoms?]</metric>
    <metric>count people with [hospitalized?]</metric>
    <metric>count people with [icu?]</metric>
    <metric>count people with [isolated?]</metric>
    <metric>count people with [immune?]</metric>
    <metric>count people with [dead? and teacher?]</metric>
    <metric>count people with [dead? and student?]</metric>
    <metric>count people with [dead? and age &gt;= 60]</metric>
    <metric>count people with [dead? and age &gt;= 60 and teacher?]</metric>
    <metric>count people with [dead? and age &lt; 60 and teacher?]</metric>
    <metric>count people with [isolated? and age &gt;= 60]</metric>
    <metric>deaths-virus</metric>
    <metric>deaths-infra</metric>
    <metric>sum [#-transmitted] of people with [not susceptible?]/ count people with [not susceptible?]</metric>
    <enumeratedValueSet variable="self-isolation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="perc-isolated">
      <value value="25"/>
      <value value="50"/>
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test2" repetitions="1" runMetricsEveryStep="true">
    <setup>load-setup</setup>
    <go>go</go>
    <metric>count people with [infected?]</metric>
    <metric>count people with [susceptible?]</metric>
    <metric>count people with [symptoms?]</metric>
    <metric>count people with [hospitalized?]</metric>
    <metric>count people with [icu?]</metric>
    <metric>count people with [isolated?]</metric>
    <metric>count people with [immune?]</metric>
    <metric>count people with [dead? and teacher?]</metric>
    <metric>count people with [dead? and student?]</metric>
    <metric>count people with [dead? and age &gt;= 60]</metric>
    <metric>count people with [dead? and age &gt;= 60 and teacher?]</metric>
    <metric>count people with [dead? and age &lt; 60 and teacher?]</metric>
    <metric>count people with [isolated? and age &gt;= 60]</metric>
    <metric>deaths-virus</metric>
    <metric>deaths-infra</metric>
    <metric>sum [#-transmitted] of people with [not susceptible?]/ count people with [not susceptible?]</metric>
    <enumeratedValueSet variable="self-isolation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="perc-isolated">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
