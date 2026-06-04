%% =========================================================
%  CÓDIGO 5 - PROCESAMIENTO DE ELECTROCARDIOGRAMA (ECG)
%  Procesamiento de Señales II - Universidad del Magdalena
%  Modalidad A: fs = 1000 Hz (adquisición simultánea con PCG)
%
%  CAMBIOS RESPECTO A LA VERSIÓN ORIGINAL (fs = 200 Hz):
%  • fs = 1000 Hz (mismo que PCG para sincronización)
%  • Parámetros Pan-Tompkins recalculados para 1000 Hz:
%    - Ventana integración: 150 ms = 150 muestras
%    - Distancia mínima R-R: 500 ms = 500 muestras
%    - Margen refinamiento pico: 40 ms = 40 muestras
%  • El resto del pipeline (filtros, FFT, espectrograma,
%    extracción de características) es idéntico al original.
%
%  PRE-REQUISITO:
%  Haber ejecutado codigo2_4_adquisicion_simultanea.m
%  → señal_ecg.mat con variables: tiempo, amplitud, fs (=1000)
%
%  SALIDA: registro_ecg.mat (mismo formato que la versión original)
%  Consumido por el Código 7.
% ==========================================================

clear; clc; close all;

%% =========================================================
%  SECCIÓN 1: CARGA DE DATOS
% ==========================================================

load('señal_ecg.mat');

% Compatibilidad de nombres de variables
if ~exist('fs', 'var')
    if exist('ECG_Data', 'var') && isfield(ECG_Data, 'fs')
        fs = ECG_Data.fs;
    else
        fs = 1000;
        fprintf('AVISO: fs no encontrada. Usando fs = %d Hz.\n', fs);
    end
end

if ~exist('amplitud', 'var')
    if exist('amplitud_ecg', 'var')
        amplitud = amplitud_ecg;
    elseif exist('ECG_Data', 'var') && isfield(ECG_Data, 'Voltaje')
        amplitud = ECG_Data.Voltaje;
    else
        error('No se encontró la variable de amplitud en señal_ecg.mat.');
    end
end

if ~exist('tiempo', 'var')
    if exist('tiempo_ecg', 'var')
        tiempo = tiempo_ecg;
    elseif exist('ECG_Data', 'var') && isfield(ECG_Data, 'Tiempo')
        tiempo = ECG_Data.Tiempo;
    else
        tiempo = (0:length(amplitud)-1)' / fs;
        fprintf('AVISO: tiempo reconstruido desde fs.\n');
    end
end

% Asegurar vectores fila
amplitud = amplitud(:)';
tiempo   = tiempo(:)';

% Definir la señal cruda
ecg_cruda = amplitud;

fprintf('=== ELECTROCARDIOGRAMA CARGADO ===\n');
fprintf('Frecuencia de muestreo : %d Hz\n', fs);
fprintf('Total de muestras      : %d\n', length(ecg_cruda));
fprintf('Duración               : %.2f s\n', max(tiempo));
fprintf('Amplitud minima        : %.6f V\n', min(ecg_cruda));
fprintf('Amplitud maxima        : %.6f V\n\n', max(ecg_cruda));

%% =========================================================
%  SECCIÓN 2: VISUALIZACIÓN DE SEÑAL CRUDA
% ==========================================================

figure('Name','ECG Crudo','NumberTitle','off');
plot(tiempo, ecg_cruda, 'b', 'LineWidth', 0.8);
xlabel('Tiempo (s)'); ylabel('Amplitud (V)');
title('Electrocardiograma Crudo (sin procesar)');
grid on;
% Ajustar limites para mejor visualizacion
xlim([0 min(60, max(tiempo))]);
ylim([-2 2]);

%% =========================================================
%  SECCIÓN 3: FILTRO PASA BANDA IIR (BUTTERWORTH)
%  Rango diagnóstico: 0.5-40 Hz
%
%  Justificación (sin cambios respecto a la versión original):
%  - 0.5 Hz inferior: elimina deriva de línea base.
%  - 40 Hz superior: conserva morfología QRS, elimina EMG
%    y ruido de red (50/60 Hz).
%  - Orden 4: compromiso atenuación/distorsión de fase.
%  Con fs = 1000 Hz los coeficientes cambian automáticamente
%  al normalizar por (fs/2), el diseño conceptual es idéntico.
% ==========================================================

fc_low_ecg  = 0.5;
fc_high_ecg = 40;
orden_iir   = 4;
Wn_ecg      = [fc_low_ecg, fc_high_ecg] / (fs/2);

[b_iir, a_iir] = butter(orden_iir, Wn_ecg, 'bandpass');
ecg_iir        = filtfilt(b_iir, a_iir, ecg_cruda);

fprintf('=== FILTRO IIR PASA BANDA (Butterworth) ===\n');
fprintf('Orden        : %d\n',      orden_iir);
fprintf('Fc inferior  : %.1f Hz\n', fc_low_ecg);
fprintf('Fc superior  : %d Hz\n\n', fc_high_ecg);

%% =========================================================
%  SECCIÓN 4: FILTRO PASA BANDA FIR (para comparación)
%  Ventana Hamming, mismo rango 0.5-40 Hz.
%  Orden 256 (el doble del original) porque con fs = 1000 Hz
%  se necesitan más coeficientes para mantener la misma
%  transición relativa en el corte de 0.5 Hz.
% ==========================================================

orden_fir = 256;
b_fir     = fir1(orden_fir, Wn_ecg, 'bandpass', hamming(orden_fir+1));
ecg_fir   = filtfilt(b_fir, 1, ecg_cruda);

fprintf('=== FILTRO FIR PASA BANDA (Hamming) ===\n');
fprintf('Orden        : %d\n',      orden_fir);
fprintf('Fc inferior  : %.1f Hz\n', fc_low_ecg);
fprintf('Fc superior  : %d Hz\n\n', fc_high_ecg);

%% =========================================================
%  SECCIÓN 5: COMPARACIÓN FIR vs IIR
% ==========================================================

N_resp = 2048;
[H_iir, w_iir] = freqz(b_iir, a_iir, N_resp, fs);
[H_fir, w_fir] = freqz(b_fir, 1,     N_resp, fs);

figure('Name','Respuesta en Frecuencia: FIR vs IIR - ECG','NumberTitle','off');

subplot(2,1,1);
plot(w_iir, 20*log10(abs(H_iir)), 'b', 'LineWidth', 1.5); hold on;
plot(w_fir, 20*log10(abs(H_fir)), 'r--', 'LineWidth', 1.5);
xlabel('Frecuencia (Hz)'); ylabel('Magnitud (dB)');
title('Respuesta en Magnitud - Filtros ECG');
legend('IIR Butterworth (ord. 4)', sprintf('FIR Hamming (ord. %d)', orden_fir));
xlim([0 fs/2]); grid on;
xline(fc_low_ecg,  'k:', 'LineWidth', 1);
xline(fc_high_ecg, 'k:', 'LineWidth', 1);

subplot(2,1,2);
plot(w_iir, unwrap(angle(H_iir))*180/pi, 'b', 'LineWidth', 1.5); hold on;
plot(w_fir, unwrap(angle(H_fir))*180/pi, 'r--', 'LineWidth', 1.5);
xlabel('Frecuencia (Hz)'); ylabel('Fase (grados)');
title('Respuesta en Fase');
legend('IIR Butterworth', 'FIR Hamming');
xlim([0 fs/2]); grid on;

fprintf('=== COMPARACIÓN FIR vs IIR ===\n');
fprintf('%-25s %-15s %-15s\n', 'Propiedad', 'IIR (Butter)', 'FIR (Hamming)');
fprintf('%s\n', repmat('-',1,57));
fprintf('%-25s %-15s %-15s\n', 'Orden',              num2str(orden_iir), num2str(orden_fir));
fprintf('%-25s %-15s %-15s\n', 'Fase',               'No lineal',    'Lineal');
fprintf('%-25s %-15s %-15s\n', 'Estabilidad',        'Condicional',  'Siempre estable');
fprintf('%-25s %-15s %-15s\n', 'Costo computacional','Bajo',         'Alto (ord. mayor)');
fprintf('%-25s %-15s %-15s\n', 'Distorsión fase',    'Sí',           'No');
fprintf('\n');

ecg_filtrada = ecg_iir;

%% =========================================================
%  SECCIÓN 6: NORMALIZACIÓN Y ENVOLVENTE (HILBERT)
% ==========================================================

ecg_norm   = ecg_filtrada / max(abs(ecg_filtrada));
analitica  = hilbert(ecg_norm);
envolvente = abs(analitica);

Wn_env         = 8 / (fs/2);
[b_env, a_env] = butter(4, Wn_env, 'low');
env_suavizada  = filtfilt(b_env, a_env, envolvente);

figure('Name','ECG Filtrado y Envolvente','NumberTitle','off');
plot(tiempo, ecg_norm, 'Color',[0.6 0.6 0.6], 'LineWidth', 0.5); hold on;
plot(tiempo, env_suavizada, 'r', 'LineWidth', 2);
xlabel('Tiempo (s)'); ylabel('Amplitud normalizada');
title('ECG Filtrado con Envolvente (Hilbert)');
legend('ECG filtrado', 'Envolvente');
grid on;
xlim([0 min(30, max(tiempo))]);
ylim([-1.2 1.2]);

%% =========================================================
%  SECCIÓN 7: DETECCIÓN DE PICOS R (Pan-Tompkins simplificado)
%  Parámetros recalculados para fs = 1000 Hz:
%  - Ventana integración 150 ms = 150 muestras
%  - Distancia mínima R-R 500 ms = 500 muestras (120 BPM máx)
%  - Margen refinamiento 40 ms  = 40 muestras
% ==========================================================

% Paso 1: Derivada
ecg_der = diff(ecg_filtrada);
ecg_der = [ecg_der(1), ecg_der];

% Paso 2: Cuadrado
ecg_sq = ecg_der .^ 2;

% Paso 3: Integración por ventana móvil (150 ms = 150 muestras)
ancho_ventana = round(0.150 * fs);   % 150 muestras a 1000 Hz
kernel        = ones(1, ancho_ventana) / ancho_ventana;
ecg_int       = conv(ecg_sq, kernel, 'same');

% Paso 4: Detección
umbral_R   = 0.50 * max(ecg_int);
dist_min_R = round(0.50 * fs);      % 500 muestras a 1000 Hz

[~, locs_R] = findpeaks(ecg_int, ...
    'MinPeakHeight',   umbral_R, ...
    'MinPeakDistance', dist_min_R);

% Refinamiento: buscar máximo real en ventana ±40 ms = ±40 muestras
margen_ms  = round(0.040 * fs);    % 40 muestras a 1000 Hz
locs_R_ref = zeros(size(locs_R));
for k = 1:length(locs_R)
    i1 = max(1, locs_R(k) - margen_ms);
    i2 = min(length(ecg_filtrada), locs_R(k) + margen_ms);
    [~, idx_local] = max(ecg_filtrada(i1:i2));
    locs_R_ref(k)  = i1 + idx_local - 1;
end
locs_R   = locs_R_ref;
tiempo_R = tiempo(locs_R);
amp_R    = ecg_filtrada(locs_R);

fprintf('=== DETECCIÓN DE PICOS R ===\n');
fprintf('fs utilizada       : %d Hz\n',   fs);
fprintf('Ventana integración: %d ms\n',   round(ancho_ventana/fs*1000));
fprintf('Distancia mín R-R  : %d ms\n',   round(dist_min_R/fs*1000));
fprintf('Umbral             : %.6f\n',     umbral_R);
fprintf('Picos R detectados : %d\n\n',    length(locs_R));

figure('Name','Detección de Picos R - ECG','NumberTitle','off');
plot(tiempo, ecg_filtrada, 'b', 'LineWidth', 0.8); hold on;
plot(tiempo_R, amp_R, 'rv', 'MarkerFaceColor','r', 'MarkerSize', 8);
xlabel('Tiempo (s)'); ylabel('Amplitud (V)');
title('ECG Filtrado - Detección de Picos R (Pan-Tompkins simplificado)');
legend('ECG filtrado', 'Picos R detectados');
grid on;
xlim([0 min(20, max(tiempo))]);
ylim([-1.5 1.5]);

%% =========================================================
%  SECCIÓN 8: ANÁLISIS EN FRECUENCIA - FFT
% ==========================================================

N_fft     = length(ecg_filtrada);
f_eje_ecg = (0:N_fft-1) * (fs/N_fft);
idx_nyq   = f_eje_ecg <= fs/2;

FFT_ecg_cruda = abs(fft(ecg_cruda))    / N_fft;
FFT_ecg_filt  = abs(fft(ecg_filtrada)) / N_fft;

figure('Name','Espectro FFT - ECG','NumberTitle','off');

subplot(2,1,1);
plot(f_eje_ecg(idx_nyq), FFT_ecg_cruda(idx_nyq), 'b', 'LineWidth', 0.8);
xlabel('Frecuencia (Hz)'); ylabel('|X(f)|');
title('Espectro FFT - ECG Crudo');
xlim([0 100]);
ylim([0 max(FFT_ecg_cruda(idx_nyq))*1.1]);
grid on;

subplot(2,1,2);
plot(f_eje_ecg(idx_nyq), FFT_ecg_filt(idx_nyq), 'r', 'LineWidth', 0.8);
xlabel('Frecuencia (Hz)'); ylabel('|X(f)|');
title('Espectro FFT - ECG Filtrado (0.5-40 Hz)');
xlim([0 60]);
ylim([0 max(FFT_ecg_filt(idx_nyq))*1.1]);
grid on;

%% =========================================================
%  SECCIÓN 9: ESPECTROGRAMA DEL ECG
% ==========================================================

ventana_ecg = round(fs * 0.25);
overlap_ecg = round(ventana_ecg * 0.90);
nfft_ecg    = 512;

figure('Name','Espectrograma ECG','NumberTitle','off');
spectrogram(ecg_filtrada, hamming(ventana_ecg), overlap_ecg, nfft_ecg, fs, 'yaxis');
title('Espectrograma - ECG Filtrado (0.5-40 Hz)');
ylim([0 60]); colorbar;
xlabel('Tiempo (s)'); ylabel('Frecuencia (Hz)');

%% =========================================================
%  SECCIÓN 10: ESTIMACIÓN DE FRECUENCIA CARDÍACA (RR)
% ==========================================================

if length(locs_R) >= 2
    intervalos_RR = diff(tiempo_R);
    FC_inst       = 60 ./ intervalos_RR;
    FC_promedio   = mean(FC_inst);
    FC_std        = std(FC_inst);
    RR_promedio   = mean(intervalos_RR);

    fprintf('=== FRECUENCIA CARDÍACA ESTIMADA POR ECG ===\n');
    fprintf('FC promedio (ECG) : %.1f BPM\n', FC_promedio);
    fprintf('FC mínima  (ECG)  : %.1f BPM\n', min(FC_inst));
    fprintf('FC máxima  (ECG)  : %.1f BPM\n', max(FC_inst));
    fprintf('Desv. estándar    : %.1f BPM\n', FC_std);
    fprintf('Intervalo RR prom : %.3f s\n\n', RR_promedio);

    figure('Name','Intervalos RR - ECG','NumberTitle','off');
    stem(tiempo_R(2:end), intervalos_RR, 'filled', 'b', 'MarkerSize', 5);
    xlabel('Tiempo (s)'); ylabel('Intervalo RR (s)');
    title('Variabilidad de Intervalos RR (HRV)');
    yline(RR_promedio, 'r--', 'Promedio', 'LineWidth', 1.5);
    grid on;
    xlim([0 min(60, max(tiempo))]);

else
    FC_promedio = NaN; FC_std = NaN;
    RR_promedio = NaN; intervalos_RR = [];
    fprintf('ADVERTENCIA: Insuficientes picos R para estimar FC.\n\n');
end

%% =========================================================
%  SECCIÓN 11: EXTRACCIÓN DE CARACTERÍSTICAS
% ==========================================================

RMS_senal    = rms(ecg_filtrada);
energia_ecg  = sum(ecg_filtrada.^2) / length(ecg_filtrada);
ptp_ecg      = peak2peak(ecg_filtrada);
duracion_s   = max(tiempo);

potencia_esp = FFT_ecg_filt(idx_nyq).^2;
f_validas    = f_eje_ecg(idx_nyq);
frec_mediana = f_validas(find(cumsum(potencia_esp) >= sum(potencia_esp)/2, 1));

fprintf('=== CARACTERÍSTICAS DEL ECG ===\n');
fprintf('RMS de la señal        : %.6f V\n',  RMS_senal);
fprintf('Energía normalizada    : %.6f V2\n', energia_ecg);
fprintf('Amplitud pico a pico   : %.4f V\n',  ptp_ecg);
fprintf('Frecuencia mediana     : %.2f Hz\n\n', frec_mediana);

%% =========================================================
%  SECCIÓN 12: IDENTIFICACIÓN DE CONDICIONES NORMALES
% ==========================================================

fprintf('=== CONDICIONES NORMALES - ECG ===\n');
fprintf('(Evaluación académica - NO es diagnóstico clínico)\n\n');

ecg_normal = true;
obs_ecg    = {};

if ~isnan(FC_promedio)
    if FC_promedio >= 60 && FC_promedio <= 100
        fprintf('[OK] FC en rango normal: %.1f BPM\n', FC_promedio);
    elseif FC_promedio < 60
        fprintf('[ATENCIÓN] Bradicardia: %.1f BPM (< 60 BPM)\n', FC_promedio);
        ecg_normal = false;
        obs_ecg{end+1} = sprintf('Bradicardia: %.1f BPM', FC_promedio);
    else
        fprintf('[ATENCIÓN] Taquicardia: %.1f BPM (> 100 BPM)\n', FC_promedio);
        ecg_normal = false;
        obs_ecg{end+1} = sprintf('Taquicardia: %.1f BPM', FC_promedio);
    end
end

n_latidos_esperados = round(FC_promedio/60 * duracion_s * 0.7);
if length(locs_R) >= n_latidos_esperados
    fprintf('[OK] Picos R detectados: %d (esperados ~%d)\n', ...
        length(locs_R), n_latidos_esperados);
else
    fprintf('[ATENCIÓN] Pocos picos R: %d (esperados ~%d)\n', ...
        length(locs_R), n_latidos_esperados);
    ecg_normal = false;
    obs_ecg{end+1} = 'Detección de picos R incompleta';
end

if ~isnan(RR_promedio)
    if RR_promedio >= 0.60 && RR_promedio <= 1.00
        fprintf('[OK] Intervalo RR promedio normal: %.3f s\n', RR_promedio);
    else
        fprintf('[ATENCIÓN] Intervalo RR atípico: %.3f s\n', RR_promedio);
        ecg_normal = false;
        obs_ecg{end+1} = sprintf('Intervalo RR atípico: %.3f s', RR_promedio);
    end
end

if length(intervalos_RR) >= 2
    CV_rr = (std(intervalos_RR) / mean(intervalos_RR)) * 100;
    if CV_rr < 20
        fprintf('[OK] Ritmo regular: CV = %.1f%%\n', CV_rr);
    else
        fprintf('[ATENCIÓN] Ritmo irregular: CV = %.1f%%\n', CV_rr);
        ecg_normal = false;
        obs_ecg{end+1} = sprintf('Ritmo irregular: CV=%.1f%%', CV_rr);
    end
else
    CV_rr = NaN;
end

if frec_mediana >= 1 && frec_mediana <= 20
    fprintf('[OK] Frecuencia mediana espectral: %.2f Hz\n', frec_mediana);
else
    fprintf('[ATENCIÓN] Frecuencia mediana atípica: %.2f Hz\n', frec_mediana);
    ecg_normal = false;
    obs_ecg{end+1} = 'Espectro ECG atípico';
end

fprintf('\n--- RESULTADO ECG ---\n');
if ecg_normal
    fprintf('REGISTRO ECG COMPATIBLE con condiciones fisiológicas esperadas.\n');
else
    fprintf('REGISTRO ECG CON OBSERVACIONES:\n');
    for i = 1:length(obs_ecg)
        fprintf('  * %s\n', obs_ecg{i});
    end
end
fprintf('(Este resultado es académico, no clínico)\n\n');

%% =========================================================
%  SECCIÓN 13: GUARDADO DE REGISTRO
%  Formato idéntico al original — el Código 7 lo consume igual.
% ==========================================================

archivo_ecg = 'registro_ecg.mat';

registro_actual.fecha         = datestr(now, 'yyyy-mm-dd HH:MM:SS');
registro_actual.fs            = fs;
registro_actual.duracion_s    = duracion_s;
registro_actual.ecg_cruda     = ecg_cruda;
registro_actual.ecg_filtrada  = ecg_filtrada;
registro_actual.tiempo        = tiempo;
registro_actual.tiempo_R      = tiempo_R;
registro_actual.picos_R       = amp_R;
registro_actual.locs_R        = locs_R;
registro_actual.intervalos_RR = intervalos_RR;
registro_actual.RR_promedio   = RR_promedio;
registro_actual.FC_promedio   = FC_promedio;
registro_actual.FC_std        = FC_std;
registro_actual.RMS_senal     = RMS_senal;
registro_actual.energia_ecg   = energia_ecg;
registro_actual.ptp_ecg       = ptp_ecg;
registro_actual.frec_mediana  = frec_mediana;
registro_actual.ecg_normal    = ecg_normal;
registro_actual.observaciones = obs_ecg;

historial_ok = false;
if isfile(archivo_ecg)
    try
        load(archivo_ecg, 'historial');
        campos_req = {'FC_std','frec_mediana','RMS_senal','intervalos_RR','picos_R'};
        ultimo = historial{end};
        for c = campos_req
            if ~isfield(ultimo, c{1}), error('campo faltante'); end
        end
        historial{end+1} = registro_actual;
        historial_ok = true;
    catch
        fprintf('AVISO: registro_ecg.mat anterior incompleto. Se sobreescribe.\n\n');
    end
end
if ~historial_ok
    historial = {registro_actual};
end

save(archivo_ecg, 'historial');
fprintf('Registro ECG guardado en: %s\n', archivo_ecg);
fprintf('Registros en historial  : %d\n', length(historial));
fprintf('Ahora ejecute el Código 6 (procesamiento PCG).\n\n');
fprintf('=== PROCESAMIENTO ECG COMPLETADO ===\n');