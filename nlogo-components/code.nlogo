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
  setup-survivors
  disaster-strikes

  ; We don't setup helpers until the end, because most would not appear until
  ; after the disaster hit
  setup-helpers
end

to setup-patches
  ;; setup centers
  ask n-of centers patches
    [set pcolor green]
  set center-patches patches with [pcolor = green]
end


to setup-survivors
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
end

to setup-helpers
  ask n-of centers center-patches [
    sprout-helpers 1 [
      set color blue
      ;fd random 25
    ]
  ]
end

to disaster-strikes
  let mdv mean-damage-value
  let sd SD-if-normal-dist

  if damage-distribution = "normal" [
   ask survivors [ set recovery-pts random-normal mdv sd ]
   ; TODO color turtles here.
  ]

  if damage-distribution = "exponential" [
    ask survivors [ set recovery-pts random-exponential mdv ]
    ; TODO color turtles here.
  ]

  if damage-distribution = "power law" [
    ask survivors [ set recovery-pts random-poisson mdv ]
    ; TODO color turtles here.
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






