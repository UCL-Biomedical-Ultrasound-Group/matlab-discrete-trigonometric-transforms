% DESCRIPTION:
%     This example script solves the 1D wave equation (written as two
%     coupled first-order equations) using a DTT-based PSTD method subject
%     to different combinations of Dirichlet and Neumann boundary
%     conditions at each end of the domain. The spatial gradients are
%     calculated using discrete cosine transforms (DCTs) and discrete sine
%     transforms (DST) chosen to enfore the required boundary condition.
%     Time integration is performed using a first-order accurate foward
%     difference scheme. A classical Fourier PSTD method is also used with
%     periodic bounday conditions for comparison. Further details are given
%     in [1].
%
%     This script reproduces Figure 5 of [1].
%
%     [1] E. Wise, J. Jaros, B. Cox, and B. Treeby, "Pseudospectral
%     time-domain (PSTD) methods for the wave equation: Realising boundary
%     conditions with discrete sine and cosine transforms", 2020.
%       
% ABOUT:
%     author      - Bradley Treeby
%     date        - 31 March 2020
%     last update - 1 April 2020
%
% Copyright (C) 2020 Bradley Treeby
%
% See also dtt1D, gradientDTT1D

% This program is free software: you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the
% Free Software Foundation, either version 3 of the License, or (at your
% option) any later version.
% 
% This program is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along
% with this program.  If not, see <https://www.gnu.org/licenses/>.

clearvars;

% =========================================================================
% DEFINE LITERALS
% =========================================================================

% shift variables used by gradientDTT1D
shift_pos = 1;
shift_neg = 2;

% transform types used by gradientDTT1D
DCT1 = 1;    % WSWS
DCT2 = 2;    % HSHS
DCT3 = 3;    % WSWA
DCT4 = 4;    % HSHA
DST1 = 5;    % WAWA
DST2 = 6;    % HAHA
DST3 = 7;    % WAWS
DST4 = 8;    % HAHS

% number of time snapshots to include in waterfall plot
waterfall_snapshots = 80;

% plot frequency for animation (time steps)
plot_freq = 50;

% =========================================================================
% DEFINE SIMULATION SETTINGS
% =========================================================================

% set the grid size
Nx   = 256;     % grid size [m]
dx   = 1/Nx;    % grid spacing [m]

% set the medium properties
c0   = 1500;    % sound speed [m/s]
rho0 = 1000;    % density [kg/m^3]

% set CFL and number of time steps
CFL  = 0.2;
Nt   = 2000;

% =========================================================================
% DEFINE INITIAL CONDITIONS
% =========================================================================

% spatial grid
x = (0:Nx - 1) * dx;

% properties of Gaussian initial condition
width = Nx * dx / 28;
offset = Nx * dx / 3;

% define initial pressure distribution on regular grid as a Gaussian
p0 = 0.5 * exp(-((x - offset) / width).^2);

% define initial particle velocity on spatially staggered grid to be
% out-of-phase with the pressure (wave will travel to the left of the
% domain)
u0 = -0.5 * exp(-((x - offset + dx/2) / width).^2) / (c0 * rho0);

% =========================================================================
% RUN SIMULATIONS USING DTT-BASED PSTD METHOD
% =========================================================================

% calculate the time step
dt = CFL * dx / c0;

% open a new figure window
plot_fig = figure;

% normalised plot axes
x_ax = (0:Nx - 1) / (Nx - 1);
t_ax = (0:waterfall_snapshots - 1) / (waterfall_snapshots - 1);

% loop over boundary conditions
for bc_ind = 1:4

    % select figure
    figure(plot_fig);
    
    % preallocate matrix to store data for waterfall plot
    p_waterfall = zeros(waterfall_snapshots, Nx);
    
    % initialise index for storing waterfall data
    waterfall_ind = 1;
    
    % define which transforms to use
    switch bc_ind
        case 1
            
            % Neumann-Neumann / WSWS
            T1 = DCT1;
            T2 = DST2;
            waterfall_title = 'Neumann-Neumann (WSWS)';
            
        case 2
            
            % Neumann-Dirichlet / WSWA
            T1 = DCT3;
            T2 = DST4;
            waterfall_title = 'Neumann-Dirichlet (WSWA)';
            
        case 3
            
            % Dirichlet-Neumann / WAWS
            T1 = DST3;
            T2 = DCT4;
            waterfall_title = 'Dirichlet-Neumann (WAWS)';
            
        case 4

            % Neumann-Neumann / WSWS
            T1 = DST1;
            T2 = DCT2;
            waterfall_title = 'Dirichlet-Dirichlet (WAWA)';
            
    end

    % assign initial condition for the pressure
    p = p0;
    
    % run the model backwards for dt/2 to calculate the initial condition
    % for u, to take into account the time staggering between p and u
    u = u0 + (dt / 2) / rho0 * gradientDTT1D(p0, dx, T1, shift_pos);
        
    % calculate pressure in a loop
    for time_ind = 1:Nt

        % update u
        u = u - dt / rho0 * gradientDTT1D(p, dx, T1, shift_pos);

        % update p
        p = p - dt * rho0 * c0^2 * gradientDTT1D(u, dx, T2, shift_neg);

        % plot pressure field
        if ~rem(time_ind, plot_freq)
            plot(x, p, 'k-');
            set(gca, 'YLim', [-1, 1]);
            drawnow;    
        end
        
        % save the pressure field
        if ~rem(time_ind, Nt / waterfall_snapshots)
            p_waterfall(waterfall_ind, :) = p;
            waterfall_ind = waterfall_ind + 1;
        end

    end
    
    % waterfall plot of evolution of field
    figure;
    waterfall(x_ax, t_ax, p_waterfall);
    view(10, 70);
    colormap([0, 0, 0]);
    set(gca, 'ZLim', [-1, 1], 'FontSize', 12);
    ylabel('time');
    zlabel('pressure');
    xlabel('position');
    title(waterfall_title);
    grid off
    
end

% =========================================================================
% RUN SIMULATIONS USING FOURIER PSTD METHOD
% =========================================================================

% select figure
figure(plot_fig);

% preallocate matrix to store data for waterfall plot
p_waterfall = zeros(waterfall_snapshots, Nx);

% initialise index for storing waterfall data
waterfall_ind = 1;

% create wavenumbers
kx = (-pi/dx):2*pi/(dx*Nx):(pi/dx - 2*pi/(dx*Nx));
kx = ifftshift(kx);

% define the gradient calculations (including grid staggering) as anonymous
% functions 
p_grad_func = @(var)( real(ifft( 1i*kx .* exp( 1i.*kx*dx/2) .* fft(var))) );
u_grad_func = @(var)( real(ifft( 1i*kx .* exp(-1i.*kx*dx/2) .* fft(var))) );

% assign initial condition for the pressure
p = p0;

% run the model backwards for dt/2 to calculate the initial condition
% for u, to take into account the time staggering between p and u
u = u0 + (dt / 2) / rho0 * p_grad_func(p0);

% calculate pressure in a loop
for time_ind = 1:Nt

    % update u
    u = u - dt / rho0 * p_grad_func(p);

    % update p
    p = p - dt * rho0 * c0^2 * u_grad_func(u);

    % plot pressure field
    if ~rem(time_ind, plot_freq)
        plot(x, p, 'k-');
        set(gca, 'YLim', [-1, 1]);
        drawnow;    
    end

    % save the pressure field
    if ~rem(time_ind, Nt / waterfall_snapshots)
        p_waterfall(waterfall_ind, :) = p;
        waterfall_ind = waterfall_ind + 1;
    end

end
    
% waterfall plot of evolution of field
figure;
waterfall(x_ax, t_ax, p_waterfall);
view(10, 70);
colormap([0, 0, 0]);
set(gca, 'ZLim', [-1, 1], 'FontSize', 12);
ylabel('time');
zlabel('pressure');
xlabel('position');
title('Periodic');
grid off

% close animation figure
close(plot_fig);