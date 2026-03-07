using DrWatson
@quickactivate "project" # Активирует проект в папке project

using DifferentialEquations
using Plots
using LaTeXStrings
using DataFrames
using JLD2

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

R = 9.0
n = 3.0

x1 = R / (n + 1)
x2 = R / (n - 1)

println("="^60)
println("РЕЗУЛЬТАТЫ РАСЧЕТА ТОЧКИ ПЕРЕХОДА")
println("="^60)
println("Случай 1 (движение к полюсу): x₁ = R/(n+1) = $(round(x1, digits=2)) км")
println("Случай 2 (движение от полюса): x₂ = R/(n-1) = $(round(x2, digits=2)) км")
println("")

v_boat = 1.0
v_guard = n * v_boat

k = sqrt(n^2 - 1)

function trajectory_eq!(dr, r, p, θ)
    k = p
    dr[1] = r[1] / k
end

r0_1 = x1
θ_span_1 = (0.0, 4π)  # Пройдем два полных оборота для наглядности
prob1 = ODEProblem(trajectory_eq!, [r0_1], θ_span_1, k)
sol1 = solve(prob1, abstol=1e-8, reltol=1e-8)

θ_coord_1 = sol1.t
r_coord_1 = [sol1.u[i][1] for i in 1:length(sol1.u)]
x_traj_1 = r_coord_1 .* cos.(θ_coord_1)
y_traj_1 = r_coord_1 .* sin.(θ_coord_1)

r0_2 = x2
θ_span_2 = (π, 5π) # Начинаем с π
prob2 = ODEProblem(trajectory_eq!, [r0_2], θ_span_2, k)
sol2 = solve(prob2, abstol=1e-8, reltol=1e-8)

θ_coord_2 = sol2.t
r_coord_2 = [sol2.u[i][1] for i in 1:length(sol2.u)]
x_traj_2 = r_coord_2 .* cos.(θ_coord_2)
y_traj_2 = r_coord_2 .* sin.(θ_coord_2)

ϕ = π/4

boat_x(t) = v_boat * t * cos(ϕ)
boat_y(t) = v_boat * t * sin(ϕ)

t_meet_1 = x1 * exp(ϕ / k) / v_boat
r_meet_1 = v_boat * t_meet_1
x_meet_1 = r_meet_1 * cos(ϕ)
y_meet_1 = r_meet_1 * sin(ϕ)

println("РЕЗУЛЬТАТЫ ДЛЯ СЛУЧАЯ 1")
println("-"^40)
println("Точка перехода (x₁): $(round(x1, digits=2)) км")
println("Параметр спирали (k = √(n²-1)): $(round(k, digits=2))")
println("Аналитическая точка встречи при φ = $(round(ϕ, digits=2)) рад:")
println("  Координаты: x = $(round(x_meet_1, digits=2)) км, y = $(round(y_meet_1, digits=2)) км")
println("  Расстояние от полюса: $(round(r_meet_1, digits=2)) км")
println("  Время встречи: $(round(t_meet_1, digits=2)) ед. времени")
println("")

θ_meet_2 = ϕ + 2π
r_meet_2 = x2 * exp((θ_meet_2 - π) / k)  # (θ - θ₀)
t_meet_2 = r_meet_2 / v_boat
x_meet_2 = r_meet_2 * cos(ϕ)
y_meet_2 = r_meet_2 * sin(ϕ)

println("РЕЗУЛЬТАТЫ ДЛЯ СЛУЧАЯ 2")
println("-"^40)
println("Точка перехода (x₂): $(round(x2, digits=2)) км")
println("Аналитическая точка встречи при φ = $(round(ϕ, digits=2)) рад:")
println("  Угол встречи катера θ_meet = $(round(θ_meet_2, digits=2)) рад ($(round(θ_meet_2/π, digits=2))π)")
println("  Координаты: x = $(round(x_meet_2, digits=2)) км, y = $(round(y_meet_2, digits=2)) км")
println("  Расстояние от полюса: $(round(r_meet_2, digits=2)) км")
println("  Время встречи: $(round(t_meet_2, digits=2)) ед. времени")

t_boat_max = max(t_meet_1, t_meet_2) * 1.2
t_boat_range = range(0, t_boat_max, length=200)
x_boat = boat_x.(t_boat_range)
y_boat = boat_y.(t_boat_range)

plt1 = plot(title="Случай 1: Катер движется к полюсу (x₁ = $(round(x1, digits=2)) км)",
            xlabel="x (км)", ylabel="y (км)", aspect_ratio=:equal, legend=:topleft,
            grid=true, size=(800, 600))

scatter!(plt1, [0], [0], label="Лодка в t=0 (полюс)", markershape=:circle, markersize=8, color=:black)

scatter!(plt1, [R], [0], label="Катер в t=0 (R, 0)", markershape=:square, markersize=8, color=:blue)

scatter!(plt1, [x1], [0], label="Точка перехода (x₁, 0)", markershape=:diamond, markersize=6, color=:green)

plot!(plt1, x_boat, y_boat, label="Траектория лодки (φ = π/4)", linewidth=2, color=:red, linestyle=:dash)

plot!(plt1, x_traj_1, y_traj_1, label="Траектория катера (спираль)", linewidth=2, color=:blue)

scatter!(plt1, [x_meet_1], [y_meet_1], label="Точка встречи", markershape=:star5, markersize=10, color=:orange)

plt2 = plot(title="Случай 2: Катер движется от полюса (x₂ = $(round(x2, digits=2)) км)",
            xlabel="x (км)", ylabel="y (км)", aspect_ratio=:equal, legend=:topleft,
            grid=true, size=(800, 600))

scatter!(plt2, [0], [0], label="Лодка в t=0 (полюс)", markershape=:circle, markersize=8, color=:black)

scatter!(plt2, [-R], [0], label="Катер в t=0 (-R, 0)", markershape=:square, markersize=8, color=:blue)

scatter!(plt2, [x2*cos(π)], [x2*sin(π)], label="Точка перехода (θ=π)", markershape=:diamond, markersize=6, color=:green)

plot!(plt2, x_boat, y_boat, label="Траектория лодки (φ = π/4)", linewidth=2, color=:red, linestyle=:dash)

plot!(plt2, x_traj_2, y_traj_2, label="Траектория катера (спираль)", linewidth=2, color=:blue)

scatter!(plt2, [x_meet_2], [y_meet_2], label="Точка встречи", markershape=:star5, markersize=10, color=:orange)

savefig(plt1, plotsdir(script_name, "case1_trajectory.png"))
savefig(plt2, plotsdir(script_name, "case2_trajectory.png"))

display(plt1)
display(plt2)

@save datadir(script_name, "results.jld2") R n x1 x2 k ϕ t_meet_1 x_meet_1 y_meet_1 t_meet_2 x_meet_2 y_meet_2
println("\nРезультаты сохранены в папке data/$(script_name)")

println("\n" * "="^60)
println("МОДЕЛИРОВАНИЕ ЗАВЕРШЕНО")
println("="^60)
