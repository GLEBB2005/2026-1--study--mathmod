# # Модель эпидемии с пороговым значением I*
#
# Модель SIR с условием: пока I(t) ≤ I*, больные изолированы
# и не заражают здоровых. При I(t) > I* начинается заражение.
#
# Вариант 1: N = 20 000, I(0) = 99, R(0) = 5.

using DrWatson
@quickactivate "project"
using OrdinaryDiffEq, Plots, DataFrames, CSV

# ### Параметры модели

N = 20_000
I0 = 99
R0 = 5
S0 = N - I0 - R0

α = 0.01   # коэффициент заболеваемости
β = 0.02   # коэффициент выздоровления
I_star = 150  # пороговое значение (выбираем > I0 для случая I0 ≤ I*)

tmax = 200.0

# ### Система ОДУ с пороговым условием

function epidemic_ode!(du, u, p, t)
    S, I, R = u
    α, β, I_star = p

    if I > I_star
        infection = α * S
    else
        infection = 0.0
    end

    recovery = β * I

    du[1] = -infection        # dS/dt
    du[2] = infection - recovery  # dI/dt
    du[3] = recovery           # dR/dt
end

# ### Случай 1: I(0) ≤ I* (I* = 150, I0 = 99)

println("=== Случай 1: I(0) ≤ I* ===")
u0_case1 = [S0, I0, R0]
p_case1 = (α, β, I_star)

prob1 = ODEProblem(epidemic_ode!, u0_case1, (0.0, tmax), p_case1)
sol1 = solve(prob1, Tsit5(), saveat = 0.5)

df1 = DataFrame(time = sol1.t, S = sol1[1, :], I = sol1[2, :], R = sol1[3, :])
CSV.write(datadir("epidemic_case1.csv"), df1)

p1 = plot(
    sol1.t, [sol1[1, :] sol1[2, :] sol1[3, :]],
    label = ["S(t)" "I(t)" "R(t)"],
    xlabel = "Время", ylabel = "Численность",
    title = "Случай 1: I(0) ≤ I* (I* = $I_star)",
    linewidth = 2,
)
savefig(plotsdir("epidemic_case1.png"))

# ### Случай 2: I(0) > I* (I* = 80, I0 = 99)

println("=== Случай 2: I(0) > I* ===")
I_star2 = 80  # порог ниже начального I0
p_case2 = (α, β, I_star2)

prob2 = ODEProblem(epidemic_ode!, u0_case1, (0.0, tmax), p_case2)
sol2 = solve(prob2, Tsit5(), saveat = 0.5)

df2 = DataFrame(time = sol2.t, S = sol2[1, :], I = sol2[2, :], R = sol2[3, :])
CSV.write(datadir("epidemic_case2.csv"), df2)

p2 = plot(
    sol2.t, [sol2[1, :] sol2[2, :] sol2[3, :]],
    label = ["S(t)" "I(t)" "R(t)"],
    xlabel = "Время", ylabel = "Численность",
    title = "Случай 2: I(0) > I* (I* = $I_star2)",
    linewidth = 2,
)
savefig(plotsdir("epidemic_case2.png"))

# ### Сравнение двух случаев по I(t)

p3 = plot(
    sol1.t, sol1[2, :],
    label = "I(t) при I* = $I_star",
    xlabel = "Время", ylabel = "Инфицированные I(t)",
    title = "Сравнение динамики I(t)",
    linewidth = 2,
)
plot!(p3, sol2.t, sol2[2, :], label = "I(t) при I* = $I_star2", linewidth = 2)
savefig(plotsdir("epidemic_comparison.png"))

println("Моделирование завершено. Результаты в data/ и plots/")