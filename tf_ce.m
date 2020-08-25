function [] = tf_ce(cse, x_coordinates, T_len, sampling_f, const)
    L_n = const.L_neg;
    L_p = const.L_pos;
    L_s = const.L_sep;
    L_tot = L_n + L_s + L_p;
    eps_e_n = const.eps_e_neg;
    eps_e_s = const.eps_e_sep;
    eps_e_p = const.eps_e_pos;
    De_n = const.Deeff_neg;
    De_s = const.Deeff_sep;
    De_p = const.Deeff_pos;

    syms x lambda k1
    syms w1 w2 k3 k4 k5 k6;

    w1 = L_n * sqrt(lambda * eps_e_n / De_n);
    w2 = L_n * sqrt(lambda * eps_e_s / De_s);
    w3 = (L_n + L_s) * sqrt(lambda * eps_e_s / De_s);
    w4 = (L_n + L_s) * sqrt(lambda * eps_e_p / De_p);

    % Solve for k3 and k4 in terms of k1
    eq1 = k1 * cos(w1) == k3 * cos(w2) + k4 * sin(w2);
    eq2 = -De_n * k1 * w1 * sin(w1) == De_s * (-k3 * w2 * sin(w2) + k4 * w2 * cos(w2));
    S_34 = solve([eq1, eq2], [k3, k4]);
    k3 = S_34.k3;
    k4 = S_34.k4;

    % Solve for k5 and k6 in terms of k3 and k4
    eq3 = k5 * cos(w4) + k6 * sin(w4) == k3 * cos(w3) + k4 * sin(w3);
    eq4 = De_p * (-k5 * w4 * sin(w4) + k6 * w4 * cos(w4)) == De_s * (-k3 * w3 *sin(w3) + k4 * w3 * cos(w3));
    S_56 = solve([eq3, eq4], [k5, k6]);
    k5 = S_56.k5;
    k6 = S_56.k6;
    
    fun_eps = @(x) eps_e_n .* ((0 <= x) & (x < L_n)) + eps_e_s .* ((L_n <= x) & (x < L_n + L_s)) + eps_e_p .* ((L_n + L_s <= x) & (x <= L_tot));
    fun_phi_n = @(x, lambda, k1) k1 .* cos(sqrt(lambda .* fun_eps(x) ./ De_n) .* x) .* ((0 <= x) & (x < L_n));
    fun_phi_s = @(x, lambda, k3, k4) ((k3 .* cos(sqrt(lambda .* fun_eps(x) ./ De_s) .* x) + k4 .* sin(sqrt(lambda .* fun_eps(x) ./ De_s) .* x))) .* ((L_n <= x) & (x < L_n + L_s)); 
    fun_phi_p = @(x, lambda, k5, k6) ((k5 .* cos(sqrt(lambda .* fun_eps(x) ./ De_p) .* x) + k6 .* sin(sqrt(lambda .* fun_eps(x) ./ De_p) .* x)) .* ((L_n + L_s <= x) & (x <= L_tot)));

    disp("Calculating PHI neg.")
    step_size = L_n / 20;
    xn_vector = 0 : step_size : L_n;
    PHI_n = @(x, lambda, k1) trapz(xn_vector, fun_phi_n(xn_vector, lambda, k1) .^ 2 .* fun_eps(xn_vector) .* (0 <= x & x <= L_n));
    disp("Calculating PHI sep.")
    step_size = L_s / 20;
    xs_vector = L_n : step_size : L_n + L_s;
    PHI_s = @(x, lambda, k3, k4) trapz(xs_vector, fun_phi_s(xs_vector, lambda, k3, k4) .^ 2 .* fun_eps(xs_vector) .* (L_n <= x & x <= L_n + L_s));
    disp("Calculate PHI pos.")
    step_size = L_p / 20;
    xp_vector = L_n + L_s : step_size : L_tot;
    PHI_p = @(x, lambda, k5, k6) trapz(xp_vector, fun_phi_p(xp_vector, lambda, k5, k6) .^ 2 .* fun_eps(xp_vector) .* (L_n + L_s <= x <= L_tot)); 

    disp("Isolate k1.")
    eq5 = PHI_n(xn_vector, lambda, k1) + PHI_s(xs_vector, lambda, k3, k4) + PHI_p(xp_vector, lambda, k5, k6) == 1;
    eq5 = isolate(eq5, k1);
    
    disp("Substitute k1.")
    k3 = subs(k3, k1, rhs(eq5));
    k4 = subs(k4, k1, rhs(eq5));
    k5 = subs(k5, k1, rhs(eq5));
    k6 = subs(k6, k1, rhs(eq5));
    k5_simple = simplify(subs(k5, k1, rhs(eq5)));
    k6_simple = simplify(subs(k6, k1, rhs(eq5)));

    disp("Calculate lambdas.");
    phi = @(x, L) eval(subs(rhs(eq5), lambda, L)) .* cos(sqrt(L .* fun_eps(x) ./ De_n) .* x) .* ((0 <= x) & (x < L_n)) ...
        + (eval(subs(k3, lambda, L)) .* cos(sqrt(L .* fun_eps(x) ./ De_s) .* x) ...
        + eval(subs(k4, lambda, L)) .* sin(sqrt(L .* fun_eps(x) ./ De_s) .* x)) .* ((L_n <= x) & (x < L_n + L_s)) ...
        + (eval(subs(k5, lambda, L)) .* cos(sqrt(L .* fun_eps(x) ./ De_p) .* x) ...
        + eval(subs(k6, lambda, L)) .* sin(sqrt(L .* fun_eps(x) ./ De_p) .* x)) .* ((L_n + L_s <= x) & (x <= L_tot));
    phi_p = @(x, L) (eval(subs(k5_simple, lambda, L)) .* cos(sqrt(L .* fun_eps(x) ./ De_p) .* x) ...
        + eval(subs(k6_simple, lambda, L)) .* sin(sqrt(L .* fun_eps(x) ./ De_p) .* x)) .* ((L_n + L_s <= x) & (x <= L_tot));

    lambda_list = [];
    l = 1;
    step = 0.3;
    h = L_p / 1000;
    a = (phi_p(L_tot - h, l) - phi(L_tot, l)) / h;
    b = (phi_p(L_tot - h, l + step) - phi(L_tot, l + step)) / h;
    c = phi_p(L_tot - h, (l + step) / 2) / h;
    while abs(c) > 10e-5
        if c > 0
            a = c;
            l = l + step / 2;
        else
            b = c;
            step = step / 2;
        end
        c = phi_p(L_tot - h, (l + step) / 2) / h;
    end
    disp(l)
    lambda_list = [lambda_list l];

    disp("Calculate constants.")
    i = 1;
    k1_list = [];
    k3_list = [];
    k4_list = [];
    k5_list = [];
    k6_list = [];

    k1_list = [k1_list eval(subs(rhs(eq5), lambda, lambda_list(i)))];
    k3_list = [k3_list eval(subs(k3, lambda, lambda_list(i)))];
    k4_list = [k4_list eval(subs(k4, lambda, lambda_list(i)))];
    k5_list = [k5_list eval(subs(k5, lambda, lambda_list(i)))]; 
    k6_list = [k6_list eval(subs(k6, lambda, lambda_list(i)))]; 
    a = trapz(xn_vector, fun_phi_n(xn_vector, lambda_list(i), k1_list(i)) .^ 2 .* fun_eps(xn_vector));
    b = trapz(xs_vector, fun_phi_s(xs_vector, lambda_list(i), k3_list(i), k4_list(i)) .^ 2 .* fun_eps(xs_vector)); 
    c = trapz(xp_vector, fun_phi_p(xp_vector, lambda_list(i), k5_list(i), k6_list(i)) .^ 2 .* fun_eps(xp_vector)); 
    sl_criteria = a + b + c;
    disp(a + b + c)
    PHI_n(xn_vector, lambda_list(i), k1_list(i)) + PHI_s(xs_vector, lambda_list(i), k3_list(i), k4_list(i)) + PHI_p(xp_vector, lambda_list(i), k5_list(i), k6_list(i)) 
    

    %phi = @(x) fun_phi_n(x, lambda_list, k1_list) + fun_phi_s(x, lambda_list, k3_list, k4_list) + fun_phi_p(x, lambda_list, k5_list, k6_list);
    %step_size = 10e-10;
    %x_vector = 0 : step_size : L_tot;
    %y_vector = [];
    %for i = 1 : size(x_vector, 2)
    %    y_vector = [y_vector sum(phi(x_vector(i)))];
    %end
    %plot(x_vector, y_vector);
end
