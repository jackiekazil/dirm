;;patches-own [ non-usage ]

globals [
  center-patches
]

breed [survivors survivor]
breed [helpers helper]

survivors-own [ home-patch j ]
helpers-own [ supplies ]


to setup
  clear-all
  setup-patches

  setup-turtles
  reset-ticks

  show survivor 1
  show [ home-patch ] of survivor 1
end

to setup-patches
  ;; setup centers
  ask n-of centers patches
    [
      set pcolor green
    ]
  set center-patches [self] of patches with [
    pcolor = green
  ]

  print center-patches
end


to setup-turtles
  ;; create survivors
  create-survivors num-survivors
  [
    set color gray
    fd random 25
    setxy random-xcor random-ycor
    set home-patch patch-here

    ;set energy 1 + random sheep-max-initial-energy
  ]

  ask n-of centers center-patches
    sprout-helpers 1 [
      set color blue
      fd random 25
      ;set energy 1 + random sheep-max-initial-energy
    ]

end



to wander
  fd 1 lt random 50 rt random 50
end

to go
  ask survivors [ wander ]
  ask helpers [ wander ]

  tick
end
