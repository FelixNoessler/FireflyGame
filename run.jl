include("FireflyGame.jl")
import .FireflyGame

let 
    scr = FireflyGame.create_fig()
    FireflyGame.game_loop(scr)  
end