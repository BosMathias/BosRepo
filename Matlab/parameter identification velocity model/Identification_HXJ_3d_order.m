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
subplot(311), plot(time, output_x, time, input), title('Position x'), legend('output','input'), xlabel('time [s]'), ylabel('position [m]')
subplot(312), plot(time, output_y), title('Position y'), xlabel('time [s]'), ylabel('position [m]')
subplot(313), plot(time, output_z), title('Position z'), xlabel('time [s]'), ylabel('position [m]')

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

FRF = output_x_f./input_f;

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
[B, A] = butter(4,0.5); % order must be higher than order of system, 
                             % adjust cut-off frquency to be higher than highest eigenfrequency of the system
                             % data sampling at 100Hz

% input filtering                           
input_filt = filter(B,A,input);
% output filtering
output_x_filt = filter(B,A,output_x);

figure('Name','filtered input input')
plot(t,input,t,input_filt),title('Input input filtered')

figure('Name','filtered output measurement')
plot(time, output_x, time, output_x_filt),title('x_{x,filt}')

%% Least squares solution for approximation of the parameters in the system
% Without filtering
% 3d order both numerator & denominator with all terms (Tustin)
% y[k] = -a2*y[k-1]-a1*y[k-2]-a0*y[k-3]+b3*u[k] + b2*u[k-1]+b1*u[k-2]+b0*u[k-3]
y = output_x(4:end);
Phi = [-output_x(3:end-1), -output_x(2:end-2), -output_x(1:end-3), input(4:end), input(3:end-1), input(2:end-2), input(1:end-3)];
theta = Phi\y;

B1 = [theta(4), theta(5), theta(6), theta(7)];
A1 = [1, theta(1), theta(2), theta(3)];

% Phi = [-output_x(3:end-1), -output_x(2:end-2), -output_x(1:end-3), input(4:end), input(3:end-1), input(2:end-2), input(1:end-3)];
% theta = Phi\y;
% 
% B1 = [theta(4), theta(5), theta(6), theta(7)];
% A1 = [1, theta(1), theta(2), theta(3)];

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
plot(t, output_x,'g')
plot(t, x1)
title('Non filtered identified transfer function vs measurement')
legend('x_{x,meas}','x_{x,sim}')
xlabel('Time [s]')
ylabel('Displacement [m]')
axis tight
subplot(212)
plot(t,output_x - x1)
title('Difference between simulation and measurement')
legend('x_{x,meas}-x_{x,sim}')
xlabel('Time [s]')
ylabel('Displacement [m]')
axis tight

figure('Name','NOT  filtered pole zero map'),pzmap(sys_d1)


%% With Butterworth filtering of in and output

y2 = output_x_filt(4:end);
Phi2 = [-output_x_filt(3:end-1), -output_x_filt(2:end-2), -output_x_filt(1:end-3), input_filt(4:end), input_filt(3:end-1), input_filt(2:end-2), input_filt(1:end-3)];
theta_filt = Phi2\y2;

B2 = [theta_filt(4),theta_filt(5),theta_filt(6), theta_filt(7)];
A2 = [1, theta_filt(1) theta_filt(2) theta_filt(3)];

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
plot(t, output_x,'g')
plot(t, output_x_filt)
plot(t,x2)
legend('x_{x,meas}', 'x_{x,filt}', 'x_{x,sim}')
title('Butterworth filtered identified transfer function vs measurement')
xlabel('Time [s]')
axis tight
ylabel('Position [m/s]')
subplot(212)
plot(t,output_x - x2)
title('Difference between simulation and measurement')
legend('x_{x,meas}-x_{x,sim}')
xlabel('Time [s]')
ylabel('Position [m/s]')
axis tight

figure('Name','Butterworth filtered Identified tf pole-zero map'),pzmap(sys_d2)



%% Least squares solution for approximation of the parameters in the system
% Without filtering
% 3d order numerator, denominator only z^3 term, others 0 (backward Euler)
% y[k] = -a2*y[k-1]-a1*y[k-2]-a0*y[k-3]+b3*u[k]
y3 = output_x(4:end);
Phi3 = [-output_x(3:end-1), -output_x(2:end-2), -output_x(1:end-3), input(4:end)];
theta3 = Phi3\y3;

B3 = [theta3(4) 0 0 0];
A3 = [1, theta3(1), theta3(2), theta3(3)];

sys_d3 = tf(B3, A3, Ts);

FRF3 = squeeze(freqresp(sys_d3,2*pi*f));

figure('Name','NOT filtered Identified transfer funtion freq response'), subplot(211)
semilogx(f, 20*log10(abs(FRF3)))
grid on
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('|FRF1|  [m]')
subplot(212),semilogx(f, 180/pi*unwrap(angle(FRF3)))
grid on
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('\phi(FRF1)  [^\circ]')

x3 = lsim(sys_d3,input,t);

figure('Name','lsim NOT filtered Identified transfer function')
subplot(211)
hold on
plot(t, output_x,'g')
plot(t, x3)
title('Non filtered identified transfer function vs measurement')
legend('x_{x,meas}','x_{x,sim}')
xlabel('Time [s]')
ylabel('Displacement [m]')
axis tight
subplot(212)
plot(t,output_x - x3)
title('Difference between simulation and measurement')
legend('x_{x,meas}-x_{x,sim}')
xlabel('Time [s]')
ylabel('Displacement [m]')
axis tight

figure('Name','NOT  filtered pole zero map'),pzmap(sys_d3)

%% Least squares solution for approximation of the parameters in the system
% Without filtering
% 2d order numerator & denominator all terms
% y[k] = -a2*y[k-1]-a1*y[k-2]-a0*y[k-3]+b3*u[k]
y4 = output_x(3:end);
Phi4 = [-output_x(2:end-1), -output_x(1:end-2), input(3:end), input(2:end-1), input(1:end-2)];
theta4 = Phi4\y4;

B4 = [theta4(3), theta4(4), theta4(5)];
A4 = [1, theta4(1) theta4(2)];

sys_d4 = tf(B4, A4, Ts);

FRF4 = squeeze(freqresp(sys_d4,2*pi*f));

figure('Name','NOT filtered Identified transfer funtion freq response'), subplot(211)
semilogx(f, 20*log10(abs(FRF4)))
grid on
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('|FRF1|  [m]')
subplot(212),semilogx(f, 180/pi*unwrap(angle(FRF4)))
grid on
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('\phi(FRF4)  [^\circ]')

x4 = lsim(sys_d4,input,t);

figure('Name','lsim NOT filtered Identified transfer function')
subplot(211)
hold on
plot(t, output_x,'g')
plot(t, x4)
title('Non filtered identified transfer function vs measurement')
legend('x_{x,meas}','x_{x,sim}')
xlabel('Time [s]')
ylabel('Displacement [m]')
axis tight
subplot(212)
plot(t,output_x - x4)
title('Difference between simulation and measurement')
legend('x_{x,meas}-x_{x,sim}')
xlabel('Time [s]')
ylabel('Displacement [m]')
axis tight

figure('Name','NOT  filtered pole zero map'),pzmap(sys_d4)

%% Least squares solution for approximation of the parameters in the system
% Without filtering
% 4th order both numerator & denominator with all terms (Tustin)
% y[k] = -a3*y[k-1]-a2*y[k-2]-a1*y[k-3]-a0*y[k-4]+b4*u[k] +
% b3*u[k-1]+b2*u[k-2]+b1*u[k-3]+b0*u[k-4]
y5 = output_x(5:end);
Phi5 = [-output_x(4:end-1), -output_x(3:end-2), -output_x(2:end-3), output_x(1:end-4), input(5:end), input(4:end-1), input(3:end-2), input(2:end-3), input(1:end-4)];
theta5 = Phi5\y5;

B5 = [theta5(5), theta5(6), theta5(7), theta5(8), theta5(9)];
A5 = [1, theta5(1), theta5(2), theta5(3), theta(4)];

% Phi = [-output_x(3:end-1), -output_x(2:end-2), -output_x(1:end-3), input(4:end), input(3:end-1), input(2:end-2), input(1:end-3)];
% theta = Phi\y;
% 
% B1 = [theta(4), theta(5), theta(6), theta(7)];
% A1 = [1, theta(1), theta(2), theta(3)];

sys_d5 = tf(B5, A5, Ts);

FRF5 = squeeze(freqresp(sys_d5,2*pi*f));

figure('Name','NOT filtered Identified transfer funtion freq response'), subplot(211)
semilogx(f, 20*log10(abs(FRF5)))
grid on
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('|FRF1|  [m]')
subplot(212),semilogx(f, 180/pi*unwrap(angle(FRF5)))
grid on
xlim([f(1) f(end)])
xlabel('f  [Hz]')
ylabel('\phi(FRF5)  [^\circ]')

x5 = lsim(sys_d5,input,t);

figure('Name','lsim NOT filtered Identified transfer function')
subplot(211)
hold on
plot(t, output_x,'g')
plot(t, x5)
title('Non filtered identified transfer function vs measurement')
legend('x_{x,meas}','x_{x,sim}')
xlabel('Time [s]')
ylabel('Displacement [m]')
axis tight
subplot(212)
plot(t,output_x - x5)
title('Difference between simulation and measurement')
legend('x_{x,meas}-x_{x,sim}')
xlabel('Time [s]')
ylabel('Displacement [m]')
axis tight

figure('Name','NOT  filtered pole zero map'),pzmap(sys_d5)