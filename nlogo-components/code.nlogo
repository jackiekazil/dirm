globals [
  center-patches
  movement-fwd
  capacity-setting
]

turtles-own [ home-patch current-need capacity]

breed [survivors survivor]
breed [helpers helper]

survivors-own [
  survival-pts recovery-pts
  recovered?
  cost-per-tick survivor-days cost-per-day
  ]

; h-type is the type of helper
; 1 is life sustaining, 2 is rebuilding & recovery
helpers-own [ h-type ]

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
    set survivor-days random-normal 3 2 ;Survives 4 days, but this can vary greatly
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
        set color yellow
        set capacity capacity-setting  ; how much a helper can carry

        set h-type random 2                  ; if h-type is 0, then survival supplies. if 1, then recovery.
        set home-patch patch-here

        setxy random-xcor random-ycor
      ]
      set helper-count (helper-count + 1)
    ]
  ]

  ask center-patches [

  ]
end

to disaster-strikes
  let mdv (100 - mean-damage-value)
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

to go-once



  ask survivors with [recovered? = False] [ survivor-move ]
  ask helpers [ helper-move]

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
  tick
end

to go
  if not any? survivors [stop]
  go-once
end


to survivor-move
  ; color oneself
  color-myself

  ;; DECIDE NEXT MOVE
  ;current-need 0 = needs survival supplies
  ;current-need 1 = needs recovery supplies
  ;current-need 2 = needs to go home to drop off supplies
  ifelse (patch-here = home-patch) and (capacity >= survivor-carrying-capacity) [set capacity 0][
    ; if what the survivor is carrying is more than their capactiy, then they need to return home for a drop off
    ifelse capacity >= survivor-carrying-capacity [ set current-need 2 ][
      ifelse survival-pts < (2 * cost-per-day)
      [set current-need 0]   ; if our survival pts are less than 2 days of supplies, we need survival supplies
      [set current-need 1]   ; if greater than or equal to, then we need recovery supplies
    ]
    ; TODO: ? Add memory and less to 1 day if they know where supplies are?
    ;TODO add cone of vision?
    ;ask standers in-cone vision-radius vision-angle
    ;ask helpers in-cone agent-vision-distance 180 [print self]

    ;; EXECUTE MOVE
    ifelse current-need = 2 [ set heading towards home-patch ] [
      let viable-helpers (helpers with [h-type = current-need])
      let nearest-neighbor min-one-of viable-helpers [ distance myself ]
      ;set destination [list xcor ycor] of nearest-neighbor
      set heading towards nearest-neighbor
    ]
    fd movement-fwd
  ]

  ;; DEDUCT SURVIVAL POINTS
  ; calculate left over survival points and die if appropriate.
  set survival-pts (survival-pts - cost-per-tick)
  if survival-pts < 5 [die]

end

to color-myself
  ifelse survival-pts > 75 [ set color 64 ]
    [ ifelse (75 <= survival-pts) and  (survival-pts > 50) [ set color 66 ]
      [ ifelse (50 <= survival-pts) and  (survival-pts > 25) [ set color 68 ]
        [ set color gray ] ] ]
end


to helper-move
    ;set label round(capacity)
    let need ([h-type] of self)

    let viable-survivors-here survivors-here with [(current-need = need) and (capacity <= 100) and (recovered? = False)]
    let viable-survivors survivors with [(current-need = need) and (recovered? = False)]

    ifelse capacity = 0 [
      ifelse patch-here = home-patch [ set capacity capacity-setting ][ go-to-refill ]
      ][
      ifelse any? viable-survivors-here
          [exchange-supplies viable-survivors-here h-type]
          [ifelse any? viable-survivors
            [find-survivors self]
            [fd movement-fwd]
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
  ;ask survivors [ print [current-need] of self ]
  let viable-survivors survivors with [current-need = need]
  let nearest-neighbor min-one-of viable-survivors [ distance myself ]
  set heading towards nearest-neighbor
  fd movement-fwd
end

to go-to-refill
  set heading towards home-patch
  fd movement-fwd
end

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



end




