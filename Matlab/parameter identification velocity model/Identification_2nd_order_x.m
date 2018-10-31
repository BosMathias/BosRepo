%%% Parameter estimation %%%
% zie ook 'test.m' !
clear all
close all

%% Load data from .mat-file

load angle_identification_x


%% Extract some signals from the data

set(0, 'DefaultLineLineWidth', 1);


% Cutoff useful data
% first_index = find(input~=0, 1);
input = input(1:end-10)';
output_x = output_x(1:end-10)';
output_y = output_y(1:end-10)';
output_z = output_z(1:end-10)';

dt = 0.02;
time = (0:dt:(length(input)-1)*dt)';

% Differentiation of x-, y-, z-position
% dt = sample time (gradient assumes timestep 1)
velocity_x = gradient(output_x)/dt;
velocity_y = gradient(output_y)/dt;
velocity_z = gradient(output_z)/dt;

% Do some plotting of the measurement data 
figure('Name','Output Measurements')
subplot(321), plot(time, output_x, time, input), title('Position x'), xlabel('time [s]'), ylabel('position [m]'), legend('output','input')
subplot(322), plot(time, velocity_x), title('Velocity x'), xlabel('time [s]'), ylabel('speed [m/s]')

subplot(323), plot(time, output_y), title('Position y'), xlabel('time [s]'), ylabel('position [m]')
subplot(324), plot(time, velocity_y), title('Velocity y'), xlabel('time [s]'), ylabel('speed [m/s]')

subplot(325), plot(time, output_z), title('Position z'), xlabel('time [s]'), ylabel('position [m]')
subplot(326), plot(time, velocity_z), title('Velocity z'), xlabel('time [s]'), ylabel('speed [m/s]')

% Input signal
figure('Name', 'Input signal')
plot(time, input)
xlabel('time [s]')
ylabel('Amplitude [-]')
axis([time(1)-1 time(end)+1 -1 1])


%% Frequency domain
Ts = dt;
fs = 1/dt;
N = length(velocity_x);
t = [0:N-1]'*Ts;
N = numel(input);
f = [0:N-1]'*(fs/N);

input_f = fft(input);
output_x_f = fft(output_x);
output_y_f = fft(output_y);
velocity_x_f = fft(velocity_x);
velocity_y_f = fft(velocity_y);

%indices = (nop+1):nop:(numel(f)/2); % alle 0 waarden er uit halen zodat niet delen door 0?
%f = f(indices);
%input_f = input_f(indices);
%velocity_x_f = velocity_x_f(indices);
%velocity_y_f = velocity_y_f(indices);

FRF = velocity_x_f./input_f;

figure('Name', 'Empirical transfer function freq response'),subplot(2,1,1),semilogx(f, 20*log10(abs(FRF)), 'LineWidth', 1)
axis tight
grid on
xlabel('f [Hz]')
xlim([f(1) f(end)])
ylabel('|FRF| [m]')
subplot(2,1,2),semilogx(f, 180/pi*unwrap(angle(FRF)), 'LineWidth', 1)
grid on
axis tight
xlabel('f  [Hz]')
ylabel('\phi(FRF) [^\circ]')
xlim([f(1) f(end)])

%% Filtering of the in- and output data using Butterworth filter
[B, A] = butter(3,0.02*5); % order must be higher than order of system, 
                             % adjust cut-off frquency to be higher than highest eigenfrequency of the system
                             % data sampling at 100Hz

% input filtering                           
input_filt = filter(B,A,input);
% output filtering
velocity_x_filt = filter(B,A,velocity_x);
velocity_y_filt = filter(B,A,velocity_y);

figure('Name','filtered input input')
plot(t,input,t,input_filt),title('Input input filtered')

figure('Name','filtered output measurement')
subplot(211), plot(time, velocity_x, time, velocity_x_filt),title('v_{x,filt}')
subplot(212), plot(time, velocity_y, time, velocity_y_filt),title('v_{y,filt}')

%% Least squares solution for approximation of the parameters in the system
% Without filtering
% y[k] = -a1*y[k-1]-a0*y[k-2]+b2*u[k]+b1*u[k-1]+b0*u[k-2]
y = velocity_x(3:end);
Phi = [-velocity_x(2:end-1), -velocity_x(1:end-2), input(3:end), input(2:end-1), input(1:end-2)];
theta = Phi\y;

B1 = [theta(3), theta(4), theta(5)];
A1 = [1, theta(1) theta(2)];

sys_d1 = tf(B1, A1, Ts);

FRF1 = squeeze(freqresp(sys_d1,2*pi*f));

figure('Name','NOT filtered Identified transfer funtion freq response'), subplot(211)
semilogx(f, 20*log10(abs(FRF1)))
grid on
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('|FRF1|  [m]')
subplot(212),semilogx(f, 180/pi*unwrap(angle(FRF1)))
grid on
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('\phi(FRF1)  [^\circ]')

x1 = lsim(sys_d1,input,t);

figure('Name','lsim NOT filtered Identified transfer function')
subplot(211)
hold on
plot(t, velocity_x,'g')
plot(t, x1)
title('Non filtered identified transfer function vs measurement')
legend('v_{x,meas}','v_{x,sim}')
xlabel('Time [s]')
ylabel('Displacement [m]')
axis tight
subplot(212)
plot(t,velocity_x - x1)
title('Difference between simulation and measurement')
legend('v_{x,meas}-v_{x,sim}')
xlabel('Time [s]')
ylabel('Displacement [m]')
axis tight

figure('Name','NOT  filtered pole zero map'),pzmap(sys_d1)


%% With Butterworth filtering of in and output

y2 = velocity_x_filt(3:end);
Phi2 = [-velocity_x_filt(2:end-1), -velocity_x_filt(1:end-2), input_filt(3:end), input_filt(2:end-1), input_filt(1:end-2)];
theta_filt = Phi2\y2;

B2 = [theta_filt(3),theta_filt(4),theta_filt(5)];
A2 = [1, theta_filt(1) theta_filt(2)];

sys_d2 = tf(B2, A2, Ts);

FRF2 = squeeze(freqresp(sys_d2,2*pi*f));

figure('Name','Butterworth filtered Identified tf freq response'),subplot(2,1,1),semilogx(f, 20*log10(abs(FRF2)))
grid on 
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('|FRF2|  [m]')
axis tight
subplot(2,1,2)
semilogx(f, 180/pi*unwrap(angle(FRF2)))
grid on
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('\phi(FRF2)  [^\circ]')

x2 = lsim(sys_d2,input,t);

figure('Name','Butterworth filtered lsim time response')
subplot(211)
hold on
plot(t, velocity_x,'g')
plot(t, velocity_x_filt)
plot(t,x2)
legend('v_{x,meas}', 'v_{x,filt}', 'v_{x,sim}')
title('Butterworth filtered identified transfer function vs measurement')
xlabel('Time [s]')
axis tight
ylabel('Velocity [m/s]')
subplot(212)
plot(t,velocity_x - x2)
title('Difference between simulation and measurement')
legend('v_{x,meas}-v_{x,sim}')
xlabel('Time [s]')
ylabel('Velocity [m/s]')
axis tight

figure('Name','Butterworth filtered Identified tf pole-zero map'),pzmap(sys_d2)

%% Taking into account KNOWN PART of the system! (b1 & b0 = 0)
% theta(4) & theta(5) (= b1 & b0) turn out to be very small. But we know
% (from physical insight) that they are EXACTLY 0!
% pk ~ partially known
% y[k] = -a1*y[k-1] - a0*y[k-2] + b2*u[k]
y_pk = velocity_x_filt(3:end);

Phi_pk = [-velocity_x_filt(2:end-1), -velocity_x_filt(1:end-2), input_filt(3:end)];
theta_pk = Phi_pk\y_pk;

% known part = z^2/1
B_k = [1, 0, 0];
A_k = [0, 0, 1];
sys_k = tf(B_k,A_k,Ts);

B_u = theta_pk(3);
A_u = [1, theta_pk(1) theta_pk(2)];
sys_u = tf(B_u,A_u, Ts);

sys_dpk = sys_k*sys_u;

FRF_pk = squeeze(freqresp(sys_dpk,2*pi*f));

figure('Name','Butter. filtered + partially known freq response'),subplot(211),semilogx(f, 20*log10(abs(FRF_pk)))
grid on 
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('|FRF_{pk}|  [m]')
axis tight
subplot(212)
semilogx(f, 180/pi*unwrap(angle(FRF_pk)))
grid on
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('\phi(FRF_{pk})  [^\circ]')

x_pk = lsim(sys_dpk,input,t);

figure('Name','Butter. filtered + partially known lsim time response')
subplot(211)
hold on
plot(t,velocity_x, 'g')
plot(t,velocity_x_filt)
plot(t,x_pk)
legend('v_{x,meas}','v_{x,filt}','v_{x,sim}')
xlabel('Time [s]')
title('Butterworth filtered + partially known identified transfer function vs measurement')
axis tight
ylabel('Velocity [m/s]')
subplot(212)
plot(t,velocity_x - x_pk)
title('Difference between simulation and measurement')
legend('v_{x,meas}-v_{x,sim}')
xlabel('Time [s]')
ylabel('Velocity [m/s]')
axis tight

figure('Name','Partially known syst: pole zero map'),pzmap(sys_dpk)

%% Comparison
figure

bode(sys_d1), grid
hold on
bode(sys_d2)
hold on
bode(sys_dpk)
legend('not filtered', 'filtered', 'partially known')

figure
plot(t,[velocity_x x1 x2 x_pk])

%% continuous time transfer function
sys_x_cont = d2c(sys_d2);
[b, a] = tfdata(sys_x_cont);
[Axc, Bxc, Cxc, Dxc] = tf2ss(b{1},a{1});


%% Save result (transfer function)
sys_2nd = sys_dpk;
sys_2nd_f = sys_d2;
sys_c2nd = sys_cpk;
save('HVJ_x','sys_2nd')
save('HvVJ_x_filtered', 'sys_2nd_f')
save('HVJ_x_cont','sys_c2nd')


%% Probeersel: integreer deze en kijk of fit op positie goed is.
z = tf('z', dt);
int_d = z*dt/(z-1);
sys_x = int_d * sys_d2;
x_sim = lsim(sys_x,input,t);

figure
plot(time, output_x, time, x_sim);

