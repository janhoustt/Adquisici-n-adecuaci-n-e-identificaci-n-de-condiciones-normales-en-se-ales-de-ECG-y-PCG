%% =========================================================
%  CODIGO 6 - PROCESAMIENTO DE FONOCARDIOGRAMA (PCG)
%  Procesamiento de Senales II - Universidad del Magdalena
%  Modulo: Microfono/Piezo | ESP32 | fs = 1000 Hz
%  Autor: [Tu nombre]
%  Fecha: 2026
%
%  PIPELINE:
%  1.  Carga de datos
%  2.  Senal cruda
%  3.  Filtro pasa banda IIR Butterworth (20-150 Hz)
%  4.  Filtro pasa banda FIR Hamming    (20-150 Hz)
%  5.  Comparacion FIR vs IIR
%  6.  Normalizacion y envolvente (Hilbert)
%  7.  Deteccion de eventos acusticos S1/S2
%  8.  Espectrograma
%  9.  Estimacion de frecuencia cardiaca acustica
%  10. Extraccion de caracteristicas
%  11. Identificacion de condiciones normales
%  12. Guardado de registro -> registro_pcg.mat
% ==========================================================

clear; clc; close all;

%% =========================================================
%  SECCION 1: CARGA DE DATOS
% ==========================================================

load('señal_pcg.mat');

% Compatibilidad de nombres de variables
if ~exist('fs', 'var')
    if exist('PCG_Data', 'var') && isfield(PCG_Data, 'fs')
        fs = PCG_Data.fs;
    else
        fs = 1000;
        fprintf('AVISO: fs no encontrada. Usando fs = %d Hz.\n', fs);
    end
end

if ~exist('amplitud', 'var')
    if exist('amplitud_pcg', 'var')
        amplitud = amplitud_pcg;
    elseif exist('PCG_Data', 'var') && isfield(PCG_Data, 'Voltaje')
        amplitud = PCG_Data.Voltaje;
    else
        error('No se encontró la variable de amplitud en señal_pcg.mat.');
    end
end

if ~exist('tiempo', 'var')
    if exist('tiempo_pcg', 'var')
        tiempo = tiempo_pcg;
    elseif exist('PCG_Data', 'var') && isfield(PCG_Data, 'Tiempo')
        tiempo = PCG_Data.Tiempo;
    else
        tiempo = (0:length(amplitud)-1)' / fs;
        fprintf('AVISO: tiempo reconstruido desde fs.\n');
    end
end

% Asegurar vectores fila
amplitud = amplitud(:)';
tiempo   = tiempo(:)';

fprintf('=== FONOCARDIOGRAMA CARGADO ===\n');
fprintf('Frecuencia de muestreo : %d Hz\n',    fs);
fprintf('Total de muestras      : %d\n',        length(amplitud));
fprintf('Duracion               : %.2f s\n',    max(tiempo));
fprintf('Amplitud minima        : %.6f V\n',    min(amplitud));
fprintf('Amplitud maxima        : %.6f V\n\n',  max(amplitud));

pcg_cruda = amplitud;

%% =========================================================
%  SECCION 2: VISUALIZACION DE SENAL CRUDA
% ==========================================================

figure('Name','PCG Cruda','NumberTitle','off');
plot(tiempo, pcg_cruda, 'Color',[0.2 0.6 0.2], 'LineWidth', 0.8);
xlabel('Tiempo (s)'); ylabel('Amplitud (V)');
title('Fonocardiograma Crudo (sin procesar)');
grid on;
xlim([0 min(30, max(tiempo))]);
ylim([-2 2]);

%% =========================================================
%  SECCION 3: FILTRO PASA BANDA IIR (BUTTERWORTH)
%  Rango S1/S2: 20-150 Hz
%  Justificacion: Los sonidos cardiacos S1 y S2 concentran
%  su energia entre 20 y 150 Hz. Por debajo de 20 Hz hay
%  movimiento y respiracion; por encima de 150 Hz predomina
%  el ruido ambiental y artefactos de friccion.
% ==========================================================

fc_low_pcg  = 20;
fc_high_pcg = 150;
orden_iir   = 4;
Wn_pcg      = [fc_low_pcg, fc_high_pcg] / (fs/2);

[b_iir, a_iir] = butter(orden_iir, Wn_pcg, 'bandpass');
pcg_iir        = filtfilt(b_iir, a_iir, pcg_cruda);

fprintf('=== FILTRO IIR PASA BANDA (Butterworth) ===\n');
fprintf('Orden        : %d\n',   orden_iir);
fprintf('Fc inferior  : %d Hz\n', fc_low_pcg);
fprintf('Fc superior  : %d Hz\n\n', fc_high_pcg);

%% =========================================================
%  SECCION 4: FILTRO PASA BANDA FIR (para comparacion)
%  Diseno por ventana de Hamming, mismo rango 20-150 Hz.
%  Ventaja: fase lineal (sin distorsion de fase).
% ==========================================================

orden_fir = 128;
b_fir     = fir1(orden_fir, Wn_pcg, 'bandpass', hamming(orden_fir+1));
pcg_fir   = filtfilt(b_fir, 1, pcg_cruda);

fprintf('=== FILTRO FIR PASA BANDA (Hamming) ===\n');
fprintf('Orden        : %d\n',   orden_fir);
fprintf('Fc inferior  : %d Hz\n', fc_low_pcg);
fprintf('Fc superior  : %d Hz\n\n', fc_high_pcg);

%% =========================================================
%  SECCION 5: COMPARACION FIR vs IIR
% ==========================================================

N_resp = 1024;
[H_iir, w_iir] = freqz(b_iir, a_iir, N_resp, fs);
[H_fir, w_fir] = freqz(b_fir, 1,     N_resp, fs);

figure('Name','Respuesta en Frecuencia: FIR vs IIR - PCG','NumberTitle','off');

subplot(2,1,1);
plot(w_iir, 20*log10(abs(H_iir)), 'b', 'LineWidth', 1.5); hold on;
plot(w_fir, 20*log10(abs(H_fir)), 'r--', 'LineWidth', 1.5);
xlabel('Frecuencia (Hz)'); ylabel('Magnitud (dB)');
title('Respuesta en Magnitud - Filtros PCG');
legend('IIR Butterworth (ord. 4)', sprintf('FIR Hamming (ord. %d)', orden_fir));
xlim([0 fs/2]); grid on;
xline(fc_low_pcg,  'k:', 'LineWidth', 1);
xline(fc_high_pcg, 'k:', 'LineWidth', 1);

subplot(2,1,2);
plot(w_iir, unwrap(angle(H_iir))*180/pi, 'b', 'LineWidth', 1.5); hold on;
plot(w_fir, unwrap(angle(H_fir))*180/pi, 'r--', 'LineWidth', 1.5);
xlabel('Frecuencia (Hz)'); ylabel('Fase (grados)');
title('Respuesta en Fase');
legend('IIR Butterworth', 'FIR Hamming');
xlim([0 fs/2]); grid on;

fprintf('=== COMPARACION FIR vs IIR ===\n');
fprintf('%-25s %-15s %-15s\n', 'Propiedad', 'IIR (Butter)', 'FIR (Hamming)');
fprintf('%s\n', repmat('-',1,57));
fprintf('%-25s %-15s %-15s\n', 'Orden',              num2str(orden_iir), num2str(orden_fir));
fprintf('%-25s %-15s %-15s\n', 'Fase',               'No lineal',   'Lineal');
fprintf('%-25s %-15s %-15s\n', 'Estabilidad',        'Condicional', 'Siempre estable');
fprintf('%-25s %-15s %-15s\n', 'Costo computacional','Bajo',        'Alto (ord. mayor)');
fprintf('%-25s %-15s %-15s\n', 'Distorsion fase',    'Si',          'No');
fprintf('\n');

pcg_filtrada = pcg_iir;

%% =========================================================
%  SECCION 6: NORMALIZACION Y ENVOLVENTE (HILBERT)
% ==========================================================

pcg_norm    = pcg_filtrada / max(abs(pcg_filtrada));
analitica   = hilbert(pcg_norm);
envolvente  = abs(analitica);

Wn_env         = 15 / (fs/2);
[b_env, a_env] = butter(4, Wn_env, 'low');
env_suavizada  = filtfilt(b_env, a_env, envolvente);

fprintf('=== ENVOLVENTE Y NORMALIZACION ===\n');
fprintf('Metodo: Transformada de Hilbert + suavizado pasa bajo (15 Hz)\n\n');

figure('Name','PCG Filtrado y Envolvente','NumberTitle','off');
plot(tiempo, pcg_norm, 'Color',[0.6 0.6 0.6], 'LineWidth', 0.5); hold on;
plot(tiempo, env_suavizada, 'r', 'LineWidth', 2);
xlabel('Tiempo (s)'); ylabel('Amplitud normalizada');
title('PCG Filtrado con Envolvente (Hilbert)');
legend('PCG filtrado', 'Envolvente');
grid on;
xlim([0 min(20, max(tiempo))]);
ylim([-0.5 1.2]);

%% =========================================================
%  SECCION 7: DETECCION DE EVENTOS ACUSTICOS (S1 y S2)
% ==========================================================

umbral_pcg   = 0.4 * max(env_suavizada);
dist_min_pcg = round(0.18 * fs);

[picos_pcg, locs_pcg] = findpeaks(env_suavizada, ...
    'MinPeakHeight',   umbral_pcg, ...
    'MinPeakDistance', dist_min_pcg);

tiempo_picos = tiempo(locs_pcg);

fprintf('=== DETECCION DE EVENTOS ACUSTICOS ===\n');
fprintf('Umbral          : %.4f (40%% del maximo)\n', umbral_pcg);
fprintf('Picos detectados: %d\n\n', length(picos_pcg));

idx_S1 = []; idx_S2 = [];
if length(locs_pcg) >= 2
    intervalos_picos = diff(tiempo_picos);
    umbral_sistole   = mean(intervalos_picos);
    i = 1;
    while i <= length(intervalos_picos)
        if intervalos_picos(i) < umbral_sistole
            idx_S1(end+1) = i;   %#ok<AGROW>
            idx_S2(end+1) = i+1; %#ok<AGROW>
            i = i + 2;
        else
            i = i + 1;
        end
    end
    fprintf('Pares S1-S2 identificados: %d\n\n', length(idx_S1));
else
    fprintf('ADVERTENCIA: Pocos picos detectados. Ajustar umbral.\n\n');
end

figure('Name','Deteccion de Sonidos S1 y S2','NumberTitle','off');
plot(tiempo, pcg_norm, 'Color',[0.7 0.7 0.7], 'LineWidth', 0.5); hold on;
plot(tiempo, env_suavizada, 'k', 'LineWidth', 1.5);
if ~isempty(idx_S1)
    plot(tiempo_picos(idx_S1), picos_pcg(idx_S1), 'bv', ...
        'MarkerFaceColor','b','MarkerSize',9);
end
if ~isempty(idx_S2)
    plot(tiempo_picos(idx_S2), picos_pcg(idx_S2), 'r^', ...
        'MarkerFaceColor','r','MarkerSize',9);
end
yline(umbral_pcg, 'g--', 'Umbral', 'LineWidth', 1);
xlabel('Tiempo (s)'); ylabel('Amplitud normalizada');
title('Fonocardiograma - Deteccion de S1 y S2');
legend('PCG filtrado','Envolvente','S1 (cierre mitral)','S2 (cierre aortico)','Umbral');
grid on;
xlim([0 min(20, max(tiempo))]);
ylim([-0.2 1.1]);

%% =========================================================
%  SECCION 8: ANALISIS EN FRECUENCIA - FFT
% ==========================================================

N_fft     = length(pcg_filtrada);
f_eje_pcg = (0:N_fft-1) * (fs/N_fft);
idx_nyq   = f_eje_pcg <= fs/2;

FFT_pcg_cruda = abs(fft(pcg_cruda))    / N_fft;
FFT_pcg_filt  = abs(fft(pcg_filtrada)) / N_fft;

figure('Name','Espectro FFT - PCG','NumberTitle','off');

subplot(2,1,1);
plot(f_eje_pcg(idx_nyq), FFT_pcg_cruda(idx_nyq), ...
    'Color',[0.2 0.6 0.2], 'LineWidth', 0.8);
xlabel('Frecuencia (Hz)'); ylabel('|X(f)|');
title('Espectro FFT - PCG Crudo');
xlim([0 300]);
ylim([0 max(FFT_pcg_cruda(idx_nyq))*1.1]);
grid on;

subplot(2,1,2);
plot(f_eje_pcg(idx_nyq), FFT_pcg_filt(idx_nyq), 'r', 'LineWidth', 0.8);
xlabel('Frecuencia (Hz)'); ylabel('|X(f)|');
title('Espectro FFT - PCG Filtrado (20-150 Hz)');
xlim([0 200]);
ylim([0 max(FFT_pcg_filt(idx_nyq))*1.1]);
grid on;

%% =========================================================
%  SECCION 9: ESPECTROGRAMA DEL FONOCARDIOGRAMA
% ==========================================================

ventana_pcg = round(fs * 0.05);
overlap_pcg = round(ventana_pcg * 0.90);
nfft_pcg    = 512;

figure('Name','Espectrograma PCG','NumberTitle','off');
spectrogram(pcg_filtrada, hamming(ventana_pcg), overlap_pcg, nfft_pcg, fs, 'yaxis');
title('Espectrograma - Fonocardiograma Filtrado');
ylim([0 200]);
colorbar;
xlabel('Tiempo (s)');
ylabel('Frecuencia (Hz)');

%% =========================================================
%  SECCION 10: ESTIMACION DE FC DESDE PCG
% ==========================================================

if length(idx_S1) >= 2
    tiempo_S1       = tiempo_picos(idx_S1);
    intervalos_S1S1 = diff(tiempo_S1);
    FC_pcg_inst     = 60 ./ intervalos_S1S1;
    FC_pcg_promedio = mean(FC_pcg_inst);
    FC_std          = std(FC_pcg_inst);

    fprintf('=== FRECUENCIA CARDIACA ESTIMADA POR PCG ===\n');
    fprintf('FC promedio (PCG) : %.1f BPM\n', FC_pcg_promedio);
    fprintf('FC minima  (PCG)  : %.1f BPM\n', min(FC_pcg_inst));
    fprintf('FC maxima  (PCG)  : %.1f BPM\n', max(FC_pcg_inst));
    fprintf('Desv. estandar    : %.1f BPM\n\n', FC_std);

    figure('Name','Ciclos Cardiacos Acusticos (S1-S1)','NumberTitle','off');
    stem(tiempo_S1(2:end), intervalos_S1S1, 'filled', 'Color',[0.8 0.2 0]);
    xlabel('Tiempo (s)'); ylabel('Periodo S1-S1 (s)');
    title('Periodicidad del Fonocardiograma (intervalos S1-S1)');
    grid on;
    xlim([0 min(60, max(tiempo))]);

else
    FC_pcg_promedio = NaN;
    FC_std          = NaN;
    intervalos_S1S1 = [];
    fprintf('ADVERTENCIA: Insuficientes eventos S1 para estimar FC.\n\n');
end

%% =========================================================
%  SECCION 11: EXTRACCION DE CARACTERISTICAS
% ==========================================================

RMS_pcg      = rms(pcg_filtrada);
energia_pcg  = sum(pcg_filtrada.^2) / length(pcg_filtrada);
ptp_pcg      = peak2peak(pcg_filtrada);

potencia_esp_pcg = FFT_pcg_filt(idx_nyq).^2;
f_validas_pcg    = f_eje_pcg(idx_nyq);
frec_mediana_pcg = f_validas_pcg(find(cumsum(potencia_esp_pcg) >= ...
    sum(potencia_esp_pcg)/2, 1));

fprintf('=== CARACTERISTICAS DEL FONOCARDIOGRAMA ===\n');
fprintf('RMS de la senal        : %.8f V\n',  RMS_pcg);
fprintf('Energia normalizada    : %.8f V2\n', energia_pcg);
fprintf('Amplitud pico a pico   : %.6f V\n',  ptp_pcg);
fprintf('Frecuencia mediana     : %.2f Hz\n\n', frec_mediana_pcg);

%% =========================================================
%  SECCION 12: IDENTIFICACION DE CONDICIONES NORMALES (PCG)
% ==========================================================

fprintf('=== CONDICIONES NORMALES - FONOCARDIOGRAMA ===\n');
fprintf('(Evaluacion academica - NO es diagnostico clinico)\n\n');

pcg_normal = true;
obs_pcg    = {};

if ~isnan(FC_pcg_promedio)
    if FC_pcg_promedio >= 60 && FC_pcg_promedio <= 100
        fprintf('[OK] FC acustica en rango normal: %.1f BPM\n', FC_pcg_promedio);
    else
        fprintf('[ATENCION] FC acustica fuera de rango: %.1f BPM\n', FC_pcg_promedio);
        pcg_normal = false;
        obs_pcg{end+1} = 'FC acustica fuera del rango esperado';
    end
end

if length(idx_S1) >= 2
    fprintf('[OK] Eventos S1/S2 detectados: %d pares\n', length(idx_S1));
else
    fprintf('[ATENCION] Pocos pares S1/S2: %d\n', length(idx_S1));
    pcg_normal = false;
    obs_pcg{end+1} = 'Escasa deteccion de ciclos acusticos';
end

if frec_mediana_pcg >= 20 && frec_mediana_pcg <= 100
    fprintf('[OK] Frecuencia mediana en rango cardiaco: %.2f Hz\n', frec_mediana_pcg);
else
    fprintf('[ATENCION] Frecuencia mediana atipica: %.2f Hz\n', frec_mediana_pcg);
    pcg_normal = false;
    obs_pcg{end+1} = 'Espectro PCG atipico';
end

if length(idx_S1) >= 2
    CV_pcg = (std(intervalos_S1S1) / mean(intervalos_S1S1)) * 100;
    if CV_pcg < 20
        fprintf('[OK] Ciclos regulares: CV = %.1f%%\n', CV_pcg);
    else
        fprintf('[ATENCION] Ciclos irregulares: CV = %.1f%%\n', CV_pcg);
        pcg_normal = false;
        obs_pcg{end+1} = 'Irregularidad en ciclos acusticos';
    end
else
    CV_pcg = NaN;
end

fprintf('\n--- RESULTADO PCG ---\n');
if pcg_normal
    fprintf('REGISTRO PCG COMPATIBLE con condiciones fisiologicas esperadas.\n');
else
    fprintf('REGISTRO PCG CON OBSERVACIONES:\n');
    for i = 1:length(obs_pcg)
        fprintf('  * %s\n', obs_pcg{i});
    end
end
fprintf('(Este resultado es academico, no clinico)\n\n');

%% =========================================================
%  SECCION 13: GUARDAR REGISTRO PCG
% ==========================================================

archivo_pcg = 'registro_pcg.mat';

registro_pcg.fecha           = datestr(now, 'yyyy-mm-dd HH:MM:SS');
registro_pcg.fs              = fs;
registro_pcg.duracion_s      = max(tiempo);
registro_pcg.pcg_cruda       = pcg_cruda;
registro_pcg.pcg_filtrada    = pcg_filtrada;
registro_pcg.tiempo_pcg      = tiempo;
registro_pcg.FC_pcg_promedio = FC_pcg_promedio;
registro_pcg.FC_std          = FC_std;
registro_pcg.RMS_pcg         = RMS_pcg;
registro_pcg.energia_pcg     = energia_pcg;
registro_pcg.ptp_pcg         = ptp_pcg;
registro_pcg.frec_mediana_pcg= frec_mediana_pcg;
registro_pcg.tiempo_picos    = tiempo_picos;
registro_pcg.picos_pcg       = picos_pcg;
registro_pcg.idx_S1          = idx_S1;
registro_pcg.idx_S2          = idx_S2;
registro_pcg.intervalos_S1S1 = intervalos_S1S1;
registro_pcg.pcg_normal      = pcg_normal;
registro_pcg.observaciones   = obs_pcg;

save(archivo_pcg, 'registro_pcg');
fprintf('Registro PCG guardado en: %s\n', archivo_pcg);
fprintf('Ahora ejecute el Codigo 7 (comparacion_ecg_pcg.m).\n\n');
fprintf('=== PROCESAMIENTO PCG COMPLETADO ===\n');