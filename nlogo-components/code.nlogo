globals [
  center-patches
  cost-per-tick
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
  setup-survivors
  disaster-strikes

  ; We don't setup helpers until the end, because most would not appear until
  ; after the disaster hit
  setup-patches
  setup-helpers
end


to setup-survivors
  ; create survivors
  create-survivors num-survivors
  [
    set color gray
    fd random 25
    setxy random-xcor random-ycor
    set home-patch patch-here
    set survival-pts 100
    set recovery-pts 100
  ]

  ; cost on survivor points per tick
  ; survivor days is the number of days that an individual can survive without water
  let survivor-days 4
  set cost-per-tick (100 / survivor-days / 16)
end

to setup-patches
  ;; setup centers
  ask n-of centers patches
    [set pcolor green]
  set center-patches patches with [pcolor = green]
end

to setup-helpers
  ; Only sprout helpers if we haven't reached out helper count
  let helper-count 0
  ask center-patches [
    if helper-count < num-helpers [
      sprout-helpers 1 [
        set color yellow
        set supplies helper-supply-capacity  ; how much a helper can carry
                                             ;set h-type  ; the type of helper it is.
      ]
      set helper-count (helper-count + 1)
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
  ask survivors [ survivor-move ]
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


;survivors-own [ survival-pts recovery-pts]
;helpers-own [ h-type supplies ]

to survivor-move
  ask survivors [

    ;Survivors make a decision at the beginning of each tick -- survive or recover.
    ;If < 2 days of supplies, then they look for survival supplies.
    ;If more, then they look for recovery supplies

    ;If survivor is at max capacity, then they have to go home to drop off supplies

    ;if S meets H-S, then they take what they can carry. If there are multiple agents, then the supplies are split equally.
    ;If S meets H-R, then they earn some value between 1 to 5.

    ; calculate left over survival points and die if appropriate.
    set survival-pts (survival-pts - cost-per-tick)
    if survival-pts = 0 [die]
    ]
end

to decide-helper-move
  ;Mobile agent has to return to supply depot, when they are out of supplies.
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






