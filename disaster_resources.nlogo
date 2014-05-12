globals [
  center-patches
  movement-fwd
  capacity-setting
  tail-fade-rate
]

turtles-own [ home-patch current-need capacity ]

breed [survivors survivor]
breed [helpers helper]
breed [tails tail]

survivors-own [ 
  survival-pts recovery-pts 
  recovered? 
  cost-per-tick survivor-days cost-per-day
  distance-traveled
  age
  ]

; h-type is the type of helper
; 1 is life sustaining, 2 is rebuilding & recovery
helpers-own [ h-type mobility ]

; all code associated with tails is based off this:
; http://stackoverflow.com/questions/21074186/netlogo-turtles-leaving-a-trail-that-fades-with-time/21081613#21081613
tails-own [ tail-type ]  ; tail-type is either helper or survivor

;;;;;;;;;;;;;
;;; Setup ;;;
;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks
  
  set movement-fwd 1
  setup-survivors
  disaster-strikes
  
  ; We don't setup helpers until the end, because most would not appear until
  ; after the disaster hit
  setup-patches
  setup-helpers
  
  set-default-shape tails "line"
  set tail-fade-rate 0.3
end


to setup-survivors   
  ; create survivors
  set-default-shape survivors "default"
  create-survivors num-survivors
  [
    set color gray
    setxy random-xcor random-ycor
    set home-patch patch-here
    set survival-pts 100
    set recovery-pts 100
    set recovered? False
    
    ; cost on survivor points per tick
    ; survivor days is the number of days that an individual can survive without water
    set survivor-days random-normal 4 1 ;Survives 3 days, but this can vary greatly
    if survivor-days < 0 [ set survivor-days .01 ]  ; This is to make sure that someone doesn't have a negative value.
    set cost-per-day (100 / survivor-days)
    set cost-per-tick (cost-per-day / 16)
  ]
  
end

to setup-patches
  ;; setup centers
  ask n-of centers patches
    [set pcolor orange]
  set center-patches patches with [pcolor = orange]
end

to setup-helpers
  ; Only sprout helpers if we haven't reached out helper count
  let helper-count 0
  let possible-cap-of-helper (total-system-supplies / num-helpers)
  
  ifelse possible-cap-of-helper > helper-supply-capacity 
    [ set capacity-setting helper-supply-capacity ]
    [ set capacity-setting possible-cap-of-helper ]
  
  while [helper-count < num-helpers] [
    ask center-patches [
        sprout-helpers 1 [
        set color 26
        set capacity capacity-setting  ; how much a helper can carry
                       
        set h-type random 2                  ; if h-type is 0, then survival supplies. if 1, then recovery.
        set home-patch patch-here       
      ]
      set helper-count (helper-count + 1)
    ]
  ]
  
  ask helpers
  [
    ifelse random-float 100 < %-helpers-mobile [ 
      set mobility True
      setxy random-xcor random-ycor] 
      [set mobility False]
  ]
end

to disaster-strikes
  let mdv (100 - mean-damage-value)
  let sd SD-if-normal-dist
  
  if damage-distribution = "normal" [ 
   ask survivors [ set recovery-pts random-normal mdv sd ]
  ]
  
  if damage-distribution = "exponential" [
    ask survivors [ set recovery-pts random-exponential mdv ]
  ]
  
  if damage-distribution = "power law" [
    ask survivors [ set recovery-pts random-poisson mdv ]
  ]
end


;;;;;;;;;;;;::;;;;;;
;;; Go & Go-once ;;;
;;;;;;;;;;;;;;;;;;;;

to go-once
  ; Hide and show survivors and helpers.
  ifelse hide-survivors?  [ ask survivors [ ht ]] [ ask survivors [ st ]]
  ifelse hide-helpers? [ ask helpers [ ht ]][ ask helpers [ st ]]
  
  ; Tails are added to watch the general movement of turtle types.
  if ((helper-tails? = True) or (survivor-tails? = True)) [
    ask tails [
      set color color - tail-fade-rate ;; make tail color darker
      if color mod 10 < 1  [ die ]     ;; die if we are almost at black
      ]
    ]
  
  if helper-tails? = False [ ask tails with [tail-type = "helper"] [ die ] ]
  if survivor-tails? = False [ ask tails with [tail-type = "survivor"] [ die ] ]
  
  ask survivors with [ recovered? = False ] [ 
    survivor-move 
    if survivor-tails? = True [
      hatch-tails 1 [ set tail-type "survivor" ]
      ]
    ]
  ask helpers [ 
    helper-move
    if helper-tails? = True [
      hatch-tails 1 [ set tail-type "helper" ]
      ]
  ]
  
  ask survivors [ 
   if survival-pts >= 100 [
     set survival-pts 100
   ]
   if recovery-pts >= 100 [ 
     set recovery-pts 100 
     set recovered? True
     if (patch-here != home-patch) [
       set heading towards home-patch
       fd movement-fwd
     ]
   ] 
  ]

  do-plotting
  
  if write-outfile? [ write-to-file ]
  
  tick
end

to go
  go-once
  
  if not any? survivors [stop]
  if mean [ recovery-pts ] of survivors > 95 [
    ; Do some extra plotting, so we can visually recognize that it has flatlined. 
    ; Adding extra ticks knowingly b/c of the extra plotting.
    do-plotting tick do-plotting tick do-plotting tick do-plotting tick do-plotting tick
    stop
    ]  
end

;;;;;;;;;;;;::;;;;;;;;
;;; Survivor moves ;;;
;;;;;;;;;;;;;;;;;;;;;;

to survivor-move
  ; color oneself
  display-myself
  set age ticks
  
  ;; DECIDE NEXT MOVE
  ;current-need 0 = needs survival supplies
  ;current-need 1 = needs recovery supplies
  ;current-need 2 = needs to go home to drop off supplies
  ifelse (patch-here = home-patch) and (capacity >= survivor-carrying-capacity) [set capacity 0][
    ; if what the survivor is carrying is more than their capactiy, then they need to return home for a drop off
    ifelse capacity >= survivor-carrying-capacity [ set current-need 2 ][
      ifelse survival-pts < (survivor-days / 2) ; survival supplies become a priority when they have less than half their survival supplies
        [set current-need 0]   ; if our survival pts are less than 2 days of supplies, we need survival supplies
        [set current-need 1]   ; if greater than or equal to, then we need recovery supplies
    ]
    
    ;; EXECUTE MOVE
    ifelse current-need = 2 [ set heading towards home-patch ] [
      let viable-helpers (helpers with [h-type = current-need])
      let nearest-neighbor min-one-of viable-helpers [ distance myself ]
      set heading towards nearest-neighbor
    ]
    fd movement-fwd
    set distance-traveled (distance-traveled + 1)
  ]

  ;; DEDUCT SURVIVAL POINTS
  ; calculate left over survival points and die if appropriate.
  set survival-pts (survival-pts - cost-per-tick)
  if survival-pts < 5 [
    ask home-patch [ set pcolor 1 ]
    die ] ; we do less than 5 b/c we had some straggles when we set at 0.
end

to display-myself
  ifelse survival-pts > 75 [ set color 64 ]
    [ ifelse (75 <= survival-pts) and  (survival-pts > 50) [ set color 66 ]
      [ ifelse (50 <= survival-pts) and  (survival-pts > 25) [ set color 68 ]
        [ set color gray ] ] ]
end


;;;;;;;;;;;;;;;;;;;;
;;; Helper moves ;;;
;;;;;;;;;;;;;;;;;;;;

to helper-move
  ;set label round(capacity)
  let need ([h-type] of self)

  let viable-survivors-here survivors-here with [(current-need = need) and (capacity <= 100) and (recovered? = False)]
  let viable-survivors survivors with [(current-need = need) and (recovered? = False)]
  
  ifelse capacity = 0 [
    ifelse patch-here = home-patch [ set capacity capacity-setting ][ go-home ] 
    ][
    ifelse any? viable-survivors-here
        [ exchange-supplies viable-survivors-here h-type]
        [ if (mobility = True) [
            ifelse any? (viable-survivors)
              [ find-survivors self ]
              [ 
                set color 21 
                ] ; do nothing & chance to an inactive state
            ]
        ]
    ]
  
    
end

to exchange-supplies [viablesurvivors local-h-type]
   
   ; h-cap = the capacity of a helper 
   let h-cap ([capacity] of self) 
   
   ;; WINNER
   ; Choose one winner to get supplies this turn from viablesurvivors.
   let winner (one-of viablesurvivors)
   ; s-cap = capacity of the winner (survivor)
   let s-cap ([capacity] of winner)
   
   ; s-need = the amount that the winner has the ability to carry.
   ; so, if carrying capacity is 30 lbs, but the winner is already 
   ; carrying 10 lbs, then the s-need is 20 lbs.
   
   let s-need 0
   ifelse local-h-type = 0
     
     ; Survival
     [ let spw ([survival-pts] of winner)
       ifelse spw <= 100
         [ set s-need (survivor-carrying-capacity - s-cap) 
           if s-need >= ( 100 - spw) [ set s-need ( 100 - spw )]
           ]        
         [ set s-need 0] ]
   
   ; Recovery
   [ let rpw ([recovery-pts] of winner)

     ifelse rpw <= 100
       [ set s-need (survivor-carrying-capacity - s-cap)
         if s-need >= ( 100 - rpw) [ set s-need ( 100 - rpw )]]
       [ set s-need 0] ]

   ; if the helper capacity is greater than the survivor need  
   ifelse h-cap > s-need [
      ; then set the helper capacity to helper capacity minus the survivor need
      set h-cap (h-cap - s-need)
      ; set survivor capacity to previous capacity and survivor need
      set s-cap (s-cap + s-need)
      ][
      ;else
      ; set survivor capacity to helper capacity -- meaning the survivor takes what the helper has left
      set s-cap h-cap
      ; set the helper's capacity to zero
      set h-cap 0
      ]
    
   ask self [
     set capacity h-cap
     ]
   ask winner [
     set capacity s-cap
     ifelse local-h-type = 0 [set survival-pts (survival-pts + s-cap)] [set recovery-pts (recovery-pts + s-cap)]
     ]

end

to find-survivors [h-in-action]
  ;find vialabe-survivors, find the closest one, set heading to the closest, then move
  let need ([h-type] of h-in-action)
  let viable-survivors survivors with [current-need = need]
  let nearest-neighbor min-one-of viable-survivors [ distance myself ]
  set heading towards nearest-neighbor
  fd movement-fwd
end

to go-home
  set heading towards home-patch
  fd movement-fwd
end


;;;;;;;;;;;;;;;;
;;; Plotting ;;;
;;;;;;;;;;;;;;;;

to do-plotting
  set-current-plot "Avg. system values"
  if any? survivors [
    set-current-plot-pen "% agents alive"
    plot (count survivors / num-survivors * 100)
    set-current-plot-pen "avg survival pts"
    plot mean [ survival-pts ] of survivors
    set-current-plot-pen "avg recovery pts"
    plot mean [ recovery-pts ] of survivors
  ]
  
  ; Plot distance distribution
  set-current-plot "Survivor Distance Traveled"
  set-current-plot-pen "distance-traveled"
  let s-traveled ([distance-traveled] of survivors)
  histogram s-traveled
  let maxbar modes [distance-traveled] of survivors
  let maxrange filter [ ? = item 0 maxbar ] [distance-traveled] of survivors
  set maxrange length maxrange
  if maxrange < 1 [ set maxrange 1 ]  ; to prevent error from happening at very low number of survivor rates.
  set-plot-y-range 0 ((maxrange) * 2)
  set-plot-pen-mode 1
  set-histogram-num-bars 20

end


;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Write info to file ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

to write-to-file
  let s-count count survivors
  let s-helpers count helpers with [h-type = 0]
  let r-helpers count helpers with [h-type = 1]
  let s-pts mean [survival-pts] of survivors
  let r-pts mean [recovery-pts] of survivors
  let s-age mean [age] of survivors
    
  file-open "output.csv"
  file-write run-label
  file-type ","
  file-write damage-distribution
  file-type "," 
  file-write mean-damage-value
  file-type "," 
  file-write SD-if-normal-dist
  file-type ","
  file-write num-survivors
  file-type "," 
  file-write survivor-carrying-capacity
  file-type "," 

  file-write s-count
  file-type "," 
  file-write s-age
  file-type "," 
  file-write s-pts
  file-type "," 
  file-write r-pts
  file-type ","
  file-write mean ([distance-traveled] of survivors)
  file-type ","
  
  file-write centers
  file-type "," 
  file-write num-helpers
  file-type "," 
 
  file-write s-helpers
  file-type ","
  file-write r-helpers
  file-type "," 
  file-write %-helpers-mobile
  file-type "," 
  file-write helper-supply-capacity
  
  file-type "," 
  file-write total-system-supplies

  file-type "\n"
  file-close
end

@#$#@#$#@
GRAPHICS-WINDOW
310
10
894
671
-1
-1
11.255
1
10
1
1
1
0
0
0
1
0
50
0
55
0
0
1
ticks
30.0

BUTTON
233
69
298
102
setup
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

BUTTON
233
105
298
138
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
902
362
965
407
survivors
count survivors
0
1
11

SLIDER
104
375
301
408
num-survivors
num-survivors
1
5000
2500
1
1
NIL
HORIZONTAL

MONITOR
902
408
959
453
Avg. life
mean [survival-pts] of survivors
0
1
11

MONITOR
966
362
1039
407
S-helpers
count helpers with [h-type = 0]
0
1
11

MONITOR
1040
362
1111
407
R-helpers
count helpers with [h-type = 1]
0
1
11

SLIDER
104
521
302
554
num-helpers
num-helpers
1
500
400
5
1
NIL
HORIZONTAL

SLIDER
104
483
302
516
centers
centers
1
20
10
1
1
NIL
HORIZONTAL

TEXTBOX
74
68
224
180
After a disaster, resource distribution occurs. This model was created to test various methods of distribution. To watch the model run, click 'setup', then 'go'.\n
11
2.0
1

TEXTBOX
76
175
374
214
_____________________________________________
10
8.0
1

TEXTBOX
73
26
241
77
Disaster Interaction Recovery Model (DIRM)
14
93.0
1

SLIDER
104
413
301
446
survivor-carrying-capacity
survivor-carrying-capacity
1
100
20
1
1
NIL
HORIZONTAL

SLIDER
105
598
303
631
helper-supply-capacity
helper-supply-capacity
1
5000
500
25
1
NIL
HORIZONTAL

CHOOSER
105
226
302
271
damage-distribution
damage-distribution
"normal" "exponential" "power law"
0

SLIDER
105
275
302
308
mean-damage-value
mean-damage-value
0
100
75
5
1
NIL
HORIZONTAL

SLIDER
105
313
302
346
SD-if-normal-dist
SD-if-normal-dist
0
100
75
5
1
NIL
HORIZONTAL

SLIDER
105
636
303
669
total-system-supplies
total-system-supplies
1
50000
20000
50
1
NIL
HORIZONTAL

BUTTON
233
141
299
174
go 1x
go-once
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
960
408
1043
453
Avg recovery
mean [recovery-pts] of survivors
0
1
11

PLOT
901
10
1312
203
Avg. system values
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"100" 1.0 0 -1513240 true "" "plot 100"
"50" 1.0 0 -4539718 true "" "plot 50"
"% agents alive" 1.0 0 -10899396 true "" ""
"avg survival pts" 1.0 0 -13791810 true "" ""
"avg recovery pts" 1.0 0 -4699768 true "" ""

SWITCH
905
506
1032
539
helper-tails?
helper-tails?
1
1
-1000

SWITCH
904
543
1033
576
survivor-tails?
survivor-tails?
1
1
-1000

SLIDER
105
559
302
592
%-helpers-mobile
%-helpers-mobile
0
100
100
5
1
NIL
HORIZONTAL

SWITCH
1037
543
1174
576
hide-survivors?
hide-survivors?
1
1
-1000

SWITCH
1036
506
1173
539
hide-helpers?
hide-helpers?
1
1
-1000

PLOT
901
207
1204
357
Survivor Distance Traveled
distance traveled
occurrences
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"distance-traveled" 1.0 0 -10899396 true "" ""

MONITOR
1045
408
1111
453
Avg. age
mean [age] of survivors
1
1
11

TEXTBOX
902
459
1334
485
__________________________________________________________________________________
10
8.0
1

TEXTBOX
76
198
170
246
System settings
12
4.0
1

TEXTBOX
906
484
1095
514
Visualization enhancements
12
93.0
1

SWITCH
230
176
369
209
write-outfile?
write-outfile?
1
1
-1000

INPUTBOX
1168
403
1308
463
run-label
H-H-Y-H
1
0
String

@#$#@#$#@
## WHAT IS IT?

Put something here.

## HOW IT WORKS

Put something here.

## HOW TO USE IT

Press SETUP and then GO.

Put something here.


## THINGS TO NOTICE

Put something here.


## THINGS TO TRY

Put something here.

## EXTENDING THE MODEL

Put something here.


## CREDITS AND REFERENCES

Create Urban Suite & Awareness model in urban suite.

Put something here.

## HOW TO CITE

Put something here.

If you mention this model in a publication, we ask that you include these citations for the model itself and for the NetLogo software:

* Felsen, M. and Wilensky, U. (2007).  NetLogo Urban Suite - Awareness model.  http://ccl.northwestern.edu/netlogo/models/UrbanSuite-Awareness.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE
Put something here.
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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.5
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
