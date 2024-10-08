using JuMP, HiGHS, ResizableArrays

epsilon = 1 # Stopping condition

c  = [10 12 11 10 9 5 5 11]
c1 = [10 12 11 10]
c2 = [9 5 5 11]
A  = [13 8 10 5 11 13 15 7
      11 14 11 12 8 13 9 10
      7 12 13 11 10 7 8 12]
A1 = [13 8 10 5
      11 14 11 12
      7 12 13 11]
A2 = [11 13 15 7
      8 13 9 10
      10 7 8 12]

D1 = [10 6 12 10
      9 11 11 10
      9 10 7 8]
D2 = [13 10 10 9
      11 11 11 7
      9 12 13 13]
b  = [126 123 114]
e1 = [74 71 69]
e2 = [70 73 73]

N = size(A,2)
rowA = size(A,1)

function SUB(subA,subc, subD, sube, y, v)
    SUB = Model(HiGHS.Optimizer)
    p = size(subD,2) #4
    numRows = size(y,1) #3

    @variable(SUB, newX[1:p]>=0)
    @constraint(SUB, smallBlock[j in 1:numRows], 
                sum(subD[j,i]*newX[i] for i in 1:p) <= sube[j])

    reducedCost = subc - Matrix(y')*subA # 1x4
    print("\nreducedCost (without x): ", reducedCost, "\n")

    @objective(SUB, Max, sum( reducedCost[i] * newX[i] for i in 1:p ) - v)
    optimize!(SUB)

    objective = objective_value(SUB)
    return vec(value.(newX)), objective
end

function RMP(x1, x2)
    RMP = Model(HiGHS.Optimizer)
    #P1 = size(x1,1)
    p1 = size(x1,2) # number of extreme points

    #P2 = size(x2,1)
    p2 = size(x2,2) # number of extreme points

    @variable(RMP, lambda1[1:p1]>=0)
    @variable(RMP, lambda2[1:p2]>=0)
    @objective(RMP, Max, sum( sum( c1[k]*x1[k,i] for k in 1:4) * lambda1[i] for i in 1:p1) + 
                         sum( sum( c2[k]*x2[k,i] for k in 1:4) * lambda2[i] for i in 1:p2) )

    @constraint(RMP, coupling[k in 1:rowA], (sum( sum(A1[k,j]*x1[j,i] for j in 1:4)*lambda1[i] for i in 1:p1) +
                                             sum( sum(A2[k,j]*x2[j,i] for j in 1:4)*lambda2[i] for i in 1:p2) ) <= b[k])
    @constraint(RMP, convex1, sum(lambda1) == 1)
    @constraint(RMP, convex2, sum(lambda2) == 1)
    optimize!(RMP)
    
    yDualVar = [shadow_price(coupling[i]) for i in 1:rowA]
    vDualVar = [shadow_price(convex1), shadow_price(convex2)]

    return yDualVar, vDualVar, value.(lambda1), value.(lambda2)
end

x1 = zeros(4,1) # Start point
x2 = zeros(4,1) # Start point
iter1 = 1
iter2 = 1
# Solve main problem
y,v,lambda1,lambda2 = RMP(x1, x2)

for maxIter in 1:5
    
    # Solve sub problem
    global new_x1, C_p1 = SUB(A1, c1, D1, e1, y, v[1])
    global new_x2, C_p2 = SUB(A2, c2, D2, e2, y, v[2])

    print("\nReduced cost1: ", C_p1)
    print("\nReduced cost2: ", C_p2,"\n\n")

    if C_p1 > epsilon
        global iter1 = iter1 + 1
        global x1 = hcat(x1, new_x1)
    end
    if C_p2 > epsilon
        global iter2 = iter2 + 1
        global x2 = hcat(x2, new_x2)
    end
    
    print("\nx values: ")
    display(x1)
    display(x2)
    
    global y,v,lambda1,lambda2 = RMP(x1, x2)
    
    print("\nDual varible (y): ", y)
    print("\nDual variable (v):", v,"\n\n")

    convCombX = [sum(x1[:,i]*lambda1[i] for i in 1:iter1);
                 sum(x2[:,i]*lambda2[i] for i in 1:iter2)]

    #print("\nSize of x array: ", size(x1,2) + size(x2,2))
    print("\n\nx values:", convCombX)
    print("\nOptimal value: ", c*convCombX,"\n\n")
    if (C_p1 <= epsilon && C_p2 <= epsilon)
        break;
    end
end

