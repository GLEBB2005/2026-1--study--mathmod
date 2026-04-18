using DrWatson
@quickactivate "project"

using DifferentialEquations
using Plots
using DataFrames
using JLD2

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

function lotka_volterra!(du, u, p, t)
    x, y = u
    a, b, c, d = p
    @inbounds begin
        du[1] = -a * x + b * x * y   # Уравнение для хищников (x)
        du[2] =  c * y - d * x * y   # Уравнение для жертв (y)
    end
    nothing
end

p = [0.12, 0.041, 0.32, 0.029]

u0 = [6.0, 11.0]

tspan = (0.0, 100.0)

prob = ODEProblem(lotka_volterra!, u0, tspan, p)
sol = solve(prob, Tsit5(), saveat=0.1)

x_star = p[3] / p[4]
y_star = p[1] / p[2]

println("="^60)
println("Модель Лотки-Вольтерры. Вариант 1")
println("="^60)
println("Параметры модели:")
println("  a (смертность хищников) = ", p[1])
println("  b (прирост хищников) = ", p[2])
println("  c (прирост жертв) = ", p[3])
println("  d (смертность жертв) = ", p[4])
println("\nНачальные условия:")
println("  x0 (хищники) = ", u0[1])
println("  y0 (жертвы) = ", u0[2])
println("\nСтационарное состояние:")
println("  x* = c/d = ", round(x_star, digits=3))
println("  y* = a/b = ", round(y_star, digits=3))

df = DataFrame(
    t = sol.t,
    x = [u[1] for u in sol.u], # Хищники
    y = [u[2] for u in sol.u]  # Жертвы
)

plt1 = plot(
    df.t, [df.x, df.y],
    label = ["Хищники (x)" "Жертвы (y)"],
    xlabel = "Время",
    ylabel = "Численность популяции",
    title = "Динамика популяций хищников и жертв",
    linewidth = 2,
    legend = :topright,
    color = [:red :green],
    size = (900, 500)
)

hline!(plt1, [x_star], color=:red, linestyle=:dash, alpha=0.5, label="x* (равновесие хищников)")
hline!(plt1, [y_star], color=:green, linestyle=:dash, alpha=0.5, label="y* (равновесие жертв)")

savefig(plotsdir(script_name, "01_population_dynamics.png"))

plt2 = plot(
    df.y, df.x,
    label = "Фазовая траектория",
    xlabel = "Численность жертв (y)",
    ylabel = "Численность хищников (x)",
    title = "Фазовый портрет системы",
    linewidth = 2,
    color = :blue,
    size = (800, 600),
    legend = :topright
)

scatter!(plt2, [y_star], [x_star], color=:black, markersize=8, label="Стационарная точка (y*, x*)")

savefig(plotsdir(script_name, "02_phase_portrait.png"))

plt3 = plot(
    layout = (2, 1),
    size = (900, 800)
)
plot!(plt3[1], df.t, [df.x, df.y], label=["Хищники" "Жертвы"], xlabel="Время", ylabel="Численность", title="Динамика популяций", color=[:red :green], linewidth=2)
hline!(plt3[1], [x_star], color=:red, linestyle=:dash, label="")
hline!(plt3[1], [y_star], color=:green, linestyle=:dash, label="")
plot!(plt3[2], df.y, df.x, label="Фазовая траектория", xlabel="Жертвы (y)", ylabel="Хищники (x)", title="Фазовый портрет", color=:blue, linewidth=2)
scatter!(plt3[2], [y_star], [x_star], color=:black, markersize=5, label="Стационарная точка")

savefig(plotsdir(script_name, "03_combined_plot.png"))

@save datadir(script_name, "simulation_results.jld2") df p u0

println("\nРезультаты сохранены в:")
println("  Графики: ", plotsdir(script_name))
println("  Данные:  ", datadir(script_name))
println("="^60)

display(plt3)
