__includes ["parcours.nls" "vector.nls" "movement.nls"]

globals [collisions escaped escaped-1 escaped-2 escaped-3 pop-tot-1 pop-tot-2 pop-tot-3 the-end escapedp1 escapedp2 totalp1 totalp2]

turtles-own [
  dead
  hp
  obj
  panic ; 0 = nothing  1 = panic A*  2 = panic flock
  speed
  panic-proba

  agent-type ;1/2/3
  inner-timer
  Ast-panic-timer

  O-
  C-
  E-
  A-
  N-

  role
]

patches-own [
 material
 onFire
 onSmoke
]
;;setup simulation

to start-fire
  ask patches [set onFire false
               set onSmoke false]
  ask one-of patches [set onFire true]
  reset-ticks
end

to set-var
  set pop-tot-1 0
  set pop-tot-2 0
  set pop-tot-3 0
  set collisions 0
  set escaped 0
  set the-end false
end

to agent-spawn
  crt agent-number
    [set color blue - 2 + random 7  ;; random shades look nice
      set size 1 ;; easier to see]
      setxy random-xcor random-ycor
      set dead false
      assign-exit
      set panic 0
      set Ast-panic-timer 0
      if personality = true
      [
        set O- random 2
        set C- random 2
        set E- random 2
        set A- random 2
        set N- random 2
      ]

      if leader-follower = true
      [
        set role random 2 ; role 0 = leader     role 1 = suiveur
        ifelse role = 0 [set color blue] [set color white]
      ]

      let r random 100
      ifelse r <= presence-type-1
      [
        set agent-type 1
        set hp base-life-1
        set speed base-speed-1
        set panic-proba more-panic-proba-1
        set inner-timer panic-timer-1
        set pop-tot-1 pop-tot-1 + 1
      ]
      [
        ifelse r > presence-type-1 and r <= presence-type-1 + presence-type-2
        [
          set agent-type 2
          set hp base-life-2
          set speed base-speed-2
          set panic-proba more-panic-proba-2
          set inner-timer panic-timer-2
          set pop-tot-2 pop-tot-2 + 1
        ]
        [
          set agent-type 3
          set hp base-life-3
          set speed base-speed-3
          set panic-proba more-panic-proba-3
          set inner-timer panic-timer-3
          set pop-tot-3 pop-tot-3 + 1
        ]

      ]

      set fobj factor-obj
      set fobs factor-obstacles
      set falign factor-align
      set fseparate factor-separate
      set fcohere factor-cohere
  ]
  ask turtles [if pcolor = brown [die]
    set path []
    set in-nodes []
    set out-nodes []
    set prefexit min-one-of patches with [exit = true][distance self]
    set current init-current
  ]

  reset-ticks
end

to check-end
  if count turtles = 0
  [ set the-end true ]
end

to make-exit
  if mouse-down?
  [ ask patches
    [ if ((abs (pxcor - mouse-xcor)) < 1) and ((abs (pycor - mouse-ycor)) < 1)
      [ set pcolor yellow
        set exit true]]]
  display
end

;;simulation treatment

to spread-fire
 ask neighbors [
    if pcolor = black or pcolor = gray[
    let r random 100
      if r <= fire-proba [set onFire true
                          set onSmoke true]
    ]
  ]
end

to spread-smoke
 ask neighbors [
    if pcolor = black[
    let r random 100
      if r <= smoke-proba [set onSmoke true]]
  ]
end

to update-color
  if onFire = true
  [set pcolor red]
  if onSmoke = true and onFire = false
  [set pcolor gray]
end

to damage
  if pcolor = gray
  [ set hp hp - smoke-damage ]
  if pcolor = red
  [ set hp hp - fire-damage ]

end

to clear-body
  if dead = true and (pcolor = red or obstacle = true)
  [ die ]
end

to assign-exit
  set prefexit one-of patches with [pcolor = yellow]
end

to check-death
  if hp <= 0 [
    set dead true
    set color green
  ]
end

to escape
  if pcolor = yellow
  [ set escaped escaped + 1

    if agent-type = 1 [set escaped-1 escaped-1 + 1]
    if agent-type = 2 [set escaped-2 escaped-2 + 1]
    if agent-type = 3 [set escaped-3 escaped-3 + 1]

    if panic = 1 [set escapedp1 escapedp1 + 1]
    if panic = 2 [set escapedp2 escapedp1 + 2]
    die
  ]
end


to go
  ask patches with [onFire = true] [update-color spread-fire]
  ask patches with [onSmoke = true] [update-color spread-smoke]
  ask turtles with [dead = false] [damage update-panic color-panic damage count-collisions]
  ask turtles with [panic = 1 and dead = false] [A* check-coll];see-exit check-coll]
  ask turtles with [panic = 2 and dead = false] [flock see-exit check-coll set inner-timer inner-timer - 1]
  ask turtles [check-death clear-body escape]
  check-end
  if the-end = true
  [ stop ]
  tick
end

to change-exit-if-fire
  let dangers patches in-cone fov-radius fov-angle with [pcolor = gray or pcolor = red]
  if any? dangers [
  let ex one-of patches with [exit = true]
  let r random 100
    if (r < objective-choice-chance)
    [set prefexit ex search]
  ]
end


to find-exit
 set obj patches in-cone fov-radius fov-angle with [exit = true]
 if any? obj
  [let x one-of obj ;;pour chaque sortie visible
  if x != prefexit ;;si la sortie n'est pas celle que l'agent connaissait
     [let r random 100
    if r < objective-choice-chance ;;l'agent peut changer de sortie favorite selon une certaine proba
    [set prefexit x ;;modifier la sortie préférée
    stop]];;ne pas continuer à parcourir les sorties encore en vues
  ]
end

to see-exit
  let ex patches in-cone fov-radius fov-angle with [exit = true]
  if any? ex
  ; [ set heading towards one-of ex ]
  [
    let x one-of ex
    ifelse personality = true
    [
      if x != prefexit and O- = 1
      [ set heading towards x ]
    ]
    [
      let r random 100
      if (r < objective-choice-chance)
      [ set heading towards x ]
    ]
   ]
end

to update-panic
  let others turtles in-cone fov-radius fov-angle with [panic != 0]
  let deads turtles in-cone fov-radius fov-angle with [color = green]

  if panic = 1
  [
   if Ast-panic-timer > 0 [
    set Ast-panic-timer Ast-panic-timer + 1
    if Ast-panic-timer >= panic-time-max
    [
      set prefexit one-of patches with [exit = true]
      search
      set Ast-panic-timer 0
    ]
    ]
  ]
  ifelse leader-follower = true
  [
    if any? others and panic = 0
    [
      ifelse role = 0
      [
        set panic 1
        set totalp1 totalp1 + 1
      ]
      [ set panic 2
      set totalp2 totalp2 + 1]
    ]
    let fire patches in-cone fov-radius fov-angle with [pcolor = red or pcolor = gray]
    if any? fire or any? deads
    [
      ifelse role = 0
      [
        set panic 1
        set totalp1 totalp1 + 1
      ]
      [ set panic 2
      set totalp2 totalp2 + 1]
    ]
  ]
  [
    if any? others and panic = 0
    [
      let r random 100
      ifelse personality = true
      [
        if r <= panic-propagation or N- = 1
        [
          set panic 1
          set totalp1 totalp1 + 1
        ]
      ]
      [
        if r <= panic-propagation
        [
          set panic 1
          set totalp1 totalp1 + 1
        ]
      ]
    ]
    let fire patches in-cone fov-radius fov-angle with [pcolor = red or pcolor = gray]
    if any? fire or any? deads
    [
      ifelse panic = 0
      [
        set panic 1
        set totalp1 totalp1 + 1
      ]
      [
        ifelse personality = true
        [
          if panic = 1 and N- = 1
          [
            let r random 100
            if r <= panic-proba
            [
              set panic 2
              if agent-type = 1 [ set speed speed + sprint-1 ]
              if agent-type = 2 [ set speed speed + sprint-2 ]
              if agent-type = 3 [ set speed speed + sprint-3 ]
            ]
          ]
        ]
        [
          if panic = 1
          [
            let r random 100
            if r <= panic-proba
            [
              set panic 2
              set totalp2 totalp2 + 1
              if agent-type = 1 [ set speed speed + sprint-1 ]
              if agent-type = 2 [ set speed speed + sprint-2 ]
              if agent-type = 3 [ set speed speed + sprint-3 ]
            ]
          ]
        ]
      ]
    ]
  ]

   if panic = 2 and inner-timer <= 0
    [
      set panic 1
      if agent-type = 1 [ set speed speed - sprint-1 set inner-timer panic-timer-1 ]
      if agent-type = 2 [ set speed speed - sprint-2 set inner-timer panic-timer-2 ]
      if agent-type = 3 [ set speed speed - sprint-3 set inner-timer panic-timer-3 ]
    ]
end

to color-panic
  if color-personality = true
  [
    if agent-type = 0 [set color red]
    if agent-type = 1 [set color cyan]
    if agent-type = 2 [set color orange]
  ]

  if color-ocean-o = true
  [
    if O- = 0 [set color white]
    if O- = 1 [set color blue]
  ]
  if color-ocean-n = true
  [
    if N- = 0 [set color white]
    if N- = 1 [set color blue]
  ]
  if color-ocean-e = true
  [
    if E- = 0 [set color white]
    if E- = 1 [set color blue]
  ]
  if color-ocean-a = true
  [
    if role = 0 [set color white]
    if role = 1 [set color blue]
  ]
    if color-using-panic = true
  [
    if panic = 1 [set color yellow]
    if panic = 2 [set color orange]
  ]
end


to panic-all
  ifelse leader-follower = true
  [
    ask turtles [set panic role + 1]
  ]
  [ ask turtles [set panic 1] ]
end



;;global simulation functions

to count-collisions
  if pcolor != black [set collisions collisions + 1]
end

to clear
  clear-all
  reset-ticks
end
@#$#@#$#@
GRAPHICS-WINDOW
12
10
577
576
-1
-1
16.9
1
10
1
1
1
0
0
0
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

TEXTBOX
1270
43
1430
61
Agent parameters
14
0.0
1

TEXTBOX
1450
43
1600
61
Movement ponderation
14
0.0
1

BUTTON
169
586
286
619
Start simulation
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

BUTTON
219
623
330
656
Spawn Agents
agent-spawn
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
448
628
549
661
Spawn Walls
spawn-walls
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
291
587
394
620
Start the fire
start-fire
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
20
593
170
611
Simulation configuration
14
0.0
1

SLIDER
1626
144
1798
177
agent-number
agent-number
0
100
27.0
1
1
NIL
HORIZONTAL

BUTTON
292
667
410
700
Clear simulation
clear
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1241
68
1413
101
min-dist
min-dist
0
20
0.0
0.5
1
NIL
HORIZONTAL

BUTTON
1
624
119
657
Draw Obstacles
make-obstacles
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
1995
74
2116
119
Number of collisions
collisions
17
1
11

TEXTBOX
2026
46
2176
64
Display
14
0.0
1

SLIDER
1242
107
1414
140
max-angle-turn
max-angle-turn
0
360
122.0
1
1
NIL
HORIZONTAL

BUTTON
334
627
440
660
Setup from Model
import-model
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1433
111
1605
144
factor-align
factor-align
0
1
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
1433
67
1605
100
factor-separate
factor-separate
0
1
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
1432
158
1604
191
factor-cohere
factor-cohere
0
1
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
1433
201
1605
234
factor-obstacles
factor-obstacles
0
1
0.8
0.1
1
NIL
HORIZONTAL

SLIDER
1627
181
1799
214
fire-proba
fire-proba
0
100
2.0
1
1
NIL
HORIZONTAL

SLIDER
1626
217
1798
250
smoke-proba
smoke-proba
0
100
6.0
1
1
NIL
HORIZONTAL

SLIDER
1627
68
1799
101
smoke-damage
smoke-damage
0
50
4.0
1
1
NIL
HORIZONTAL

SLIDER
1627
105
1799
138
fire-damage
fire-damage
0
50
20.0
1
1
NIL
HORIZONTAL

BUTTON
125
624
210
657
Draw Exit
make-exit
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
1997
181
2056
226
NIL
escaped
17
1
11

SLIDER
1239
426
1411
459
fov-angle
fov-angle
0
360
80.0
1
1
NIL
HORIZONTAL

SLIDER
1239
465
1411
498
fov-radius
fov-radius
0
10
3.0
1
1
patches
HORIZONTAL

SLIDER
1433
244
1605
277
factor-obj
factor-obj
0
1
0.8
0.1
1
NIL
HORIZONTAL

SLIDER
1241
150
1425
183
objective-choice-chance
objective-choice-chance
0
100
61.0
1
1
NIL
HORIZONTAL

BUTTON
399
587
554
620
Compute A* Algorithm
search-turtles
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
82
669
199
702
Panic all agents
panic-all
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1240
192
1412
225
next-patch-range
next-patch-range
0
20
3.0
1
1
NIL
HORIZONTAL

TEXTBOX
1640
43
1828
67
Environment parameters
14
0.0
1

TEXTBOX
1252
407
1402
425
Vision
14
0.0
1

TEXTBOX
1243
288
1599
359
IMPORTANT! \nYou must setup walls, exit and agents before computing A* algorithm !\nStart the fire just before to start simulation !
14
0.0
1

PLOT
593
656
884
806
Population
temps
Agent
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Escaped" 1.0 0 -1184463 true "" "plot escaped"
"Total" 1.0 0 -16777216 true "" "plot count turtles"

MONITOR
1997
132
2054
177
agents
count turtles
17
1
11

TEXTBOX
1631
316
1781
334
Type 1 (faible)
14
0.0
1

TEXTBOX
1783
316
1933
334
Type 2 (+ de vie)
14
0.0
1

TEXTBOX
1961
318
2111
336
Type 3 (+ de vitesse)
14
0.0
1

SLIDER
1579
350
1751
383
base-life-1
base-life-1
0
150
60.0
1
1
NIL
HORIZONTAL

SLIDER
1579
394
1751
427
base-speed-1
base-speed-1
0
2
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
1579
435
1751
468
more-panic-proba-1
more-panic-proba-1
0
100
77.0
1
1
NIL
HORIZONTAL

SLIDER
1759
349
1931
382
base-life-2
base-life-2
0
150
150.0
1
1
NIL
HORIZONTAL

SLIDER
1942
349
2114
382
base-life-3
base-life-3
0
150
90.0
1
1
NIL
HORIZONTAL

SLIDER
1579
473
1751
506
presence-type-1
presence-type-1
0
100 - presence-type-2 - presence-type-3
34.0
1
1
NIL
HORIZONTAL

SLIDER
1760
394
1932
427
base-speed-2
base-speed-2
0
2
1.2
0.1
1
NIL
HORIZONTAL

SLIDER
1942
394
2114
427
base-speed-3
base-speed-3
0
2
2.0
0.1
1
NIL
HORIZONTAL

SLIDER
1759
435
1931
468
more-panic-proba-2
more-panic-proba-2
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
1944
435
2116
468
more-panic-proba-3
more-panic-proba-3
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
1759
473
1931
506
presence-type-2
presence-type-2
0
100 - presence-type-1 - presence-type-3
33.0
1
1
NIL
HORIZONTAL

SLIDER
1943
472
2115
505
presence-type-3
presence-type-3
0
100 - presence-type-1 - presence-type-2
33.0
1
1
NIL
HORIZONTAL

PLOT
586
10
1209
409
Agent Type Population
temps
agent
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Type 1" 1.0 0 -5825686 true "" "plot (count turtles with [agent-type = 1] * 100) / (pop-tot-1 + 1)"
"Type 2" 1.0 0 -11221820 true "" "plot (count turtles with [agent-type = 2] * 100) / (pop-tot-2 + 1)"
"Type 3" 1.0 0 -2674135 true "" "plot (count turtles with [agent-type = 3] * 100) / (pop-tot-3 + 1)"
"Escaped type 1" 1.0 0 -8630108 true "" "plot escaped-1"
"Escaped type 2" 1.0 0 -13345367 true "" "plot escaped-2"
"Escaped type 3" 1.0 0 -955883 true "" "plot escaped-3"

SLIDER
1579
514
1751
547
sprint-1
sprint-1
0
1.0
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
1759
514
1931
547
sprint-2
sprint-2
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
1943
514
2115
547
sprint-3
sprint-3
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
1580
552
1752
585
panic-timer-1
panic-timer-1
0
20
12.0
1
1
tick
HORIZONTAL

SLIDER
1759
553
1931
586
panic-timer-2
panic-timer-2
0
20
6.0
1
1
tick
HORIZONTAL

SLIDER
1944
553
2116
586
panic-timer-3
panic-timer-3
0
20
20.0
1
1
tick
HORIZONTAL

SLIDER
1810
68
1982
101
panic-propagation
panic-propagation
0
100
20.0
1
1
NIL
HORIZONTAL

TEXTBOX
1877
43
2027
61
Panic
14
0.0
1

TEXTBOX
1582
601
1749
674
O -> Openness to experience\nC -> Conscientiousness\nE -> Extraversion\nA -> Agreeableness\nN -> Neuroticism\n
11
0.0
1

SWITCH
1900
616
2040
649
leader-follower
leader-follower
0
1
-1000

SWITCH
1767
616
1889
649
personality
personality
0
1
-1000

BUTTON
3
668
75
701
NIL
set-var
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
586
413
1191
646
Escaped 
time
number
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot escapedp1"
"pen-1" 1.0 0 -955883 true "" "plot escapedp2"

SWITCH
1215
546
1363
579
color-personality
color-personality
1
1
-1000

SWITCH
1214
582
1363
615
color-using-panic
color-using-panic
1
1
-1000

SWITCH
1216
622
1348
655
color-ocean-o
color-ocean-o
0
1
-1000

SWITCH
1215
658
1347
691
color-ocean-n
color-ocean-n
0
1
-1000

SWITCH
1345
621
1477
654
color-ocean-e
color-ocean-e
0
1
-1000

SWITCH
1342
657
1474
690
color-ocean-a
color-ocean-a
0
1
-1000

SLIDER
1237
236
1409
269
panic-time-max
panic-time-max
0
50
10.0
1
1
NIL
HORIZONTAL

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
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
