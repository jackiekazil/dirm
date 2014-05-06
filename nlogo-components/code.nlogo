globals [
  center-patches
]

turtles-own [ home-patch next-move capacity ]

breed [survivors survivor]
breed [helpers helper]

survivors-own [ survival-pts recovery-pts]
helpers-own [ h-type supplies ]
; h-type is the type of helper
  ; 1 is life sustaining, 2 is rebuilding & recovery

to setup
  clear-all
  reset-ticks
  setup-patches
  setup-turtles

  disaster-strikes
end

to setup-patches
  ;; setup centers
  ask n-of centers patches
    [set pcolor green]
  set center-patches patches with [pcolor = green]
end


to setup-turtles
  ;; create survivors
  create-survivors num-survivors
  [
    set color gray
    fd random 25
    setxy random-xcor random-ycor
    set home-patch patch-here
    set survival-pts 100
    set recovery-pts 100

    ;set sur
    ;set energy 1 + random sheep-max-initial-energy
  ]

  ask n-of centers center-patches [
    sprout-helpers 1 [
      set color blue
      ;fd random 25
    ]
  ]
end

to disaster-strikes

  if disaster-type = "earthquake" [
    print disaster-type
  ]
  if disaster-type = "tsunami" [
    print disaster-type
  ]

  if disaster-type = "hurricane" [
    print disaster-type
  ]
end



to go
  ask survivors [ decide-survivor-move ]
  ask helpers [ decide-helper-move ]
  tick
end

to wander
  fd 1 lt random 50 rt random 50
end

to move
  ;ifelse survival-pts > 50 [][]
  ;ifelse reporter [ commands1 ] [ commands2 ]
end

to decide-survivor-move
  ask survivors [wander]
end

to decide-helper-move
end



;todo
;function that directs survivors on a turn
;see helper - move towards them
;memory?

;todo
;function that directors helpers on a turn
;see person who needs help -- move towards them
;memory?


;todo
;estimate and apply damage points by disaster pattern
; include random

;todo
;plots to create






