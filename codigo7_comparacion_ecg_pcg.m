%% 
%% =========================================================
%  CÓDIGO 7 - COMPARACIÓN ECG vs FONOCARDIOGRAMA (PCG)
%  Procesamiento de Señales II - Universidad del Magdalena
%  Modalidad A: Adquisición simultánea sincronizada
%
%  DIFERENCIA CLAVE respecto a la versión Modalidad B:
%  Las señales comparten el mismo vector de tiempo (misma fs,
%  misma marca de inicio). Esto permite calcular el retardo
%  electromecánico R-S1 directamente, muestra a muestra.
%
%  SECCIONES NUEVAS respecto a Modalidad B:
%  - Sección 4: Superposición sincronizada ECG + PCG
%  - Sección 7: Cálculo del retardo R-S1 (nuevo)
%  - Sección 8: Figura retardo R-S1 por ciclo (nueva)
%
%  PRE-REQUISITOS:
%  - Código 5 ejecutado → registro_ecg.mat
%  - Código 6 ejecutado → registro_pcg.mat
% ==========================================================

clear; clc; close all;

%% =========================================================
%  SECCIÓN 1: CARGA DE REGISTROS
% ==========================================================

if ~isfile('registro_ecg.mat')
    error('No se encontró registro_ecg.mat. Ejecute primero el Código 5.');
end
load('registro_ecg.mat', 'historial');
ecg_reg = historial{end};

if ~isfile('registro_pcg.mat')
    error('No se encontró registro_pcg.mat. Ejecute primero el Código 6.');
end
load('registro_pcg.mat', 'registro_pcg');
pcg_reg = registro_pcg;

fprintf('=== COMPARACIÓN ECG vs FONOCARDIOGRAMA — MODALIDAD A ===\n');
fprintf('ECG registrado : %s\n',   ecg_reg.fecha);
fprintf('PCG registrado : %s\n',   pcg_reg.fecha);
fprintf('fs ECG         : %d Hz\n', ecg_reg.fs);
fprintf('fs PCG         : %d Hz\n\n', pcg_reg.fs);

% Verificar que ambas señales tienen la misma fs (requisito Modalidad A)
if ecg_reg.fs ~= pcg_reg.fs
    warning(['Las señales tienen fs diferente (%d vs %d Hz).\n' ...
             'Verifique que usó el código de adquisición simultánea.\n' ...
             'El retardo R-S1 puede no ser preciso.'], ...
             ecg_reg.fs, pcg_reg.fs);
end

% Verificar campos críticos
campos_ecg = {'FC_std','FC_promedio','RR_promedio','intervalos_RR', ...
              'ecg_filtrada','tiempo','tiempo_R','picos_R','locs_R', ...
              'fs','duracion_s','RMS_senal','frec_mediana'};
for k = 1:length(campos_ecg)
    if ~isfield(ecg_reg, campos_ecg{k})
        error('Campo faltante en registro_ecg.mat: %s', campos_ecg{k});
    end
end

%% =========================================================
%  SECCIÓN 2: SEÑALES NORMALIZADAS
% ==========================================================

ecg_norm = ecg_reg.ecg_filtrada / max(abs(ecg_reg.ecg_filtrada));
pcg_norm = pcg_reg.pcg_filtrada / max(abs(pcg_reg.pcg_filtrada));

%% =========================================================
%  SECCIÓN 3: DURACIÓN COMÚN
% ==========================================================

t_comun   = min(max(ecg_reg.tiempo), max(pcg_reg.tiempo_pcg));
mask_ecg  = ecg_reg.tiempo     <= t_comun;
mask_pcg  = pcg_reg.tiempo_pcg <= t_comun;

t_ecg_c    = ecg_reg.tiempo(mask_ecg);
ecg_norm_c = ecg_norm(mask_ecg);
t_pcg_c    = pcg_reg.tiempo_pcg(mask_pcg);
pcg_norm_c = pcg_norm(mask_pcg);

%% =========================================================
%  SECCIÓN 4: SUPERPOSICIÓN SINCRONIZADA ECG + PCG
%  (3 paneles: ECG solo / PCG solo / Superpuestas)
% ==========================================================

figure('Name','Comparación ECG vs PCG: Señales Filtradas (Sincronizadas)', ...
    'NumberTitle','off','Position',[50 100 1100 750]);

% Panel superior: ECG
subplot(3,1,1);
plot(t_ecg_c, ecg_norm_c, 'b', 'LineWidth', 1); hold on;
mask_R = ecg_reg.tiempo_R <= t_comun;
plot(ecg_reg.tiempo_R(mask_R), ones(sum(mask_R),1)*0.92, ...
    'v','Color','y','MarkerFaceColor','y','MarkerSize',6);
ylabel('Amplitud norm.'); xlabel('Tiempo (s)');
title('ECG Filtrado (0.5-40 Hz) — Picos R marcados');
legend('ECG filtrado','Picos R','Location','northeast');
xlim([0 t_comun]); ylim([-1.1 1.1]); grid on;

% Panel central: PCG
subplot(3,1,2);
plot(t_pcg_c, pcg_norm_c, 'Color',[0.1 0.7 0.2], 'LineWidth', 1); hold on;
if ~isempty(pcg_reg.idx_S1)
    t_S1 = pcg_reg.tiempo_picos(pcg_reg.idx_S1);
    mask_S1 = t_S1 <= t_comun;
    plot(t_S1(mask_S1), pcg_reg.picos_pcg(pcg_reg.idx_S1(mask_S1))*0.92, ...
        'v','Color','c','MarkerFaceColor','c','MarkerSize',6);
end
ylabel('Amplitud norm.'); xlabel('Tiempo (s)');
title('PCG Filtrado (20-150 Hz) — Eventos S1 marcados');
legend('PCG filtrado','S1','Location','northeast');
xlim([0 t_comun]); ylim([-1.1 1.1]); grid on;

% Panel inferior: Superposición
subplot(3,1,3);
plot(t_ecg_c, ecg_norm_c, 'b', 'LineWidth', 1.2); hold on;
plot(t_pcg_c, pcg_norm_c, 'Color',[0.1 0.7 0.2], 'LineWidth', 1.0);
ylabel('Amplitud norm.'); xlabel('Tiempo (s)');
title('Superposición sincronizada: ECG y PCG — Modalidad A');
legend('ECG filtrado (0.5-40 Hz)','PCG filtrado (20-150 Hz)','Location','northeast');
xlim([0 t_comun]); ylim([-1.2 1.2]); grid on;

sgtitle('Comparación de Señales Filtradas Sincronizadas: ECG vs PCG', ...
    'FontSize',13,'FontWeight','bold');

%% =========================================================
%  SECCIÓN 5: VENTANA CORTA SINCRONIZADA (5 segundos)
% ==========================================================

t_ventana  = min(5, t_comun);
mask_ecg_v = ecg_reg.tiempo     <= t_ventana;
mask_pcg_v = pcg_reg.tiempo_pcg <= t_ventana;

figure('Name','Superposición ECG-PCG: Ventana 5 s (Sincronizada)', ...
    'NumberTitle','off','Position',[80 80 1000 480]);

plot(ecg_reg.tiempo(mask_ecg_v), ecg_norm(mask_ecg_v), ...
    'b','LineWidth',1.5); hold on;
plot(pcg_reg.tiempo_pcg(mask_pcg_v), pcg_norm(mask_pcg_v), ...
    'Color',[0.1 0.7 0.2],'LineWidth',1.2);

% Picos R
mask_R_v = ecg_reg.tiempo_R <= t_ventana;
plot(ecg_reg.tiempo_R(mask_R_v), ones(sum(mask_R_v),1)*1.05, ...
    'v','Color','y','MarkerFaceColor','y','MarkerSize',7);

% Eventos S1
if ~isempty(pcg_reg.idx_S1)
    t_S1 = pcg_reg.tiempo_picos(pcg_reg.idx_S1);
    mask_S1_v = t_S1 <= t_ventana;
    plot(t_S1(mask_S1_v), ones(sum(mask_S1_v),1)*-1.05, ...
        '^','Color','c','MarkerFaceColor','c','MarkerSize',7);
end

yline(0,'k--','LineWidth',0.5);
xlabel('Tiempo (s)'); ylabel('Amplitud normalizada');
title(sprintf('Superposición ECG-PCG Sincronizada — Primeros %.0f segundos', t_ventana));
legend('ECG filtrado','PCG filtrado','Picos R (ECG)','S1 (PCG)','Location','northeast');
xlim([0 t_ventana]); ylim([-1.3 1.3]); grid on;

annotation('textbox',[0.13 0.01 0.75 0.05], ...
    'String',['Modalidad A: Señales sincronizadas. El retardo entre pico R y S1 ' ...
              'es el retardo electromecánico (~20-100 ms en adulto normal).'], ...
    'FitBoxToText','on','EdgeColor','none', ...
    'FontSize',8,'Color',[0.4 0.4 0.4],'HorizontalAlignment','center');

%% =========================================================
%  SECCIÓN 6: COMPARACIÓN ESPECTRAL FFT
% ==========================================================

N_ecg = length(ecg_reg.ecg_filtrada);
N_pcg = length(pcg_reg.pcg_filtrada);

f_ecg = (0:N_ecg-1) * (ecg_reg.fs / N_ecg);
f_pcg = (0:N_pcg-1) * (pcg_reg.fs  / N_pcg);

idx_ecg = f_ecg <= ecg_reg.fs/2;
idx_pcg = f_pcg <= pcg_reg.fs/2;

FFT_ecg = abs(fft(ecg_reg.ecg_filtrada)) / N_ecg;
FFT_pcg = abs(fft(pcg_reg.pcg_filtrada)) / N_pcg;

figure('Name','Comparación Espectral ECG vs PCG','NumberTitle','off');

subplot(2,1,1);
plot(f_ecg(idx_ecg), FFT_ecg(idx_ecg), 'b','LineWidth',1);
xlabel('Frecuencia (Hz)'); ylabel('|X(f)|');
title(sprintf('Espectro ECG (fs=%d Hz) — Rango 0.5-40 Hz', ecg_reg.fs));
xlim([0 60]); grid on;

subplot(2,1,2);
plot(f_pcg(idx_pcg), FFT_pcg(idx_pcg), 'Color',[0.1 0.7 0.2],'LineWidth',1);
xlabel('Frecuencia (Hz)'); ylabel('|X(f)|');
title(sprintf('Espectro PCG (fs=%d Hz) — Rango 20-150 Hz', pcg_reg.fs));
xlim([0 200]); grid on;

%% =========================================================
%  SECCIÓN 7: CÁLCULO DEL RETARDO R-S1
%  ─────────────────────────────────────────────────────────
%  SOLO posible en Modalidad A (señales sincronizadas).
%
%  Método:
%  Para cada pico R del ECG, se busca el evento S1 del PCG
%  más próximo que ocurra DESPUÉS del pico R (dentro de una
%  ventana de búsqueda de 0 a 200 ms, rango fisiológico del
%  retardo electromecánico en adulto normal).
%
%  Retardo electromecánico R-S1 normal: 20-100 ms
%  (tiempo entre la activación eléctrica ventricular y el
%  cierre de la válvula mitral, primer ruido cardíaco S1).
% ==========================================================

fprintf('=== RETARDO ELECTROMECÁNICO R-S1 (Modalidad A) ===\n');

ventana_RS1_max = 0.200;   % 200 ms máximo de búsqueda post-R
ventana_RS1_min = 0.010;   % 10 ms mínimo (evitar falsos inmediatos)

retardos_RS1 = [];
pares_R_idx  = [];
pares_S1_idx = [];

if ~isempty(pcg_reg.idx_S1) && length(ecg_reg.tiempo_R) >= 1

    tiempo_S1_todos = pcg_reg.tiempo_picos(pcg_reg.idx_S1);

    for k = 1:length(ecg_reg.tiempo_R)
        t_R = ecg_reg.tiempo_R(k);

        % Buscar eventos S1 dentro de la ventana [t_R+10ms, t_R+200ms]
        candidatos = find( ...
            tiempo_S1_todos >= (t_R + ventana_RS1_min) & ...
            tiempo_S1_todos <= (t_R + ventana_RS1_max) );

        if ~isempty(candidatos)
            % Tomar el S1 más cercano al pico R dentro de la ventana
            [~, idx_min] = min(tiempo_S1_todos(candidatos) - t_R);
            idx_S1_par   = candidatos(idx_min);

            retardo_k = tiempo_S1_todos(idx_S1_par) - t_R;
            retardos_RS1(end+1) = retardo_k * 1000;   % Convertir a ms
            pares_R_idx(end+1)  = k;
            pares_S1_idx(end+1) = idx_S1_par;
        end
    end

    if ~isempty(retardos_RS1)
        retardo_promedio = mean(retardos_RS1);
        retardo_std      = std(retardos_RS1);
        retardo_min      = min(retardos_RS1);
        retardo_max      = max(retardos_RS1);

        fprintf('Pares R-S1 encontrados  : %d\n',    length(retardos_RS1));
        fprintf('Retardo R-S1 promedio   : %.1f ms\n', retardo_promedio);
        fprintf('Desviación estándar     : %.1f ms\n', retardo_std);
        fprintf('Retardo mínimo          : %.1f ms\n', retardo_min);
        fprintf('Retardo máximo          : %.1f ms\n', retardo_max);

        % Interpretación fisiológica (académica)
        fprintf('\n--- Interpretación del retardo R-S1 ---\n');
        if retardo_promedio >= 20 && retardo_promedio <= 100
            fprintf('[OK] Retardo R-S1 en rango fisiológico esperado (20-100 ms).\n');
            fprintf('     Consistente con función de conducción normal.\n');
        elseif retardo_promedio < 20
            fprintf('[ATENCIÓN] Retardo muy corto (< 20 ms).\n');
            fprintf('     Posible solapamiento de detecciones o artefacto.\n');
        else
            fprintf('[ATENCIÓN] Retardo prolongado (> 100 ms).\n');
            fprintf('     Puede indicar artefacto, ruido o detección incorrecta de S1.\n');
        end
        fprintf('(Interpretación académica - NO es diagnóstico clínico)\n\n');

    else
        fprintf('No se encontraron pares R-S1 válidos.\n');
        fprintf('Verifique la detección de S1 en el Código 6.\n\n');
        retardo_promedio = NaN; retardo_std = NaN;
        retardo_min = NaN; retardo_max = NaN;
    end
else
    fprintf('Datos insuficientes para calcular retardo R-S1.\n\n');
    retardo_promedio = NaN; retardo_std = NaN;
    retardo_min = NaN; retardo_max = NaN;
end

%% =========================================================
%  SECCIÓN 8: FIGURA RETARDO R-S1 POR CICLO
% ==========================================================

if ~isnan(retardo_promedio) && ~isempty(retardos_RS1)

    figure('Name','Retardo R-S1 por Ciclo Cardíaco','NumberTitle','off', ...
        'Position',[100 100 1000 550]);

    subplot(2,1,1);
    % Señales superpuestas con flechas indicando los pares R-S1
    t_lim = min(8, t_comun);
    mask_plot = ecg_reg.tiempo <= t_lim;
    plot(ecg_reg.tiempo(mask_plot), ecg_norm(mask_plot), ...
        'b','LineWidth',1.2); hold on;
    mask_plot_pcg = pcg_reg.tiempo_pcg <= t_lim;
    plot(pcg_reg.tiempo_pcg(mask_plot_pcg), pcg_norm(mask_plot_pcg), ...
        'Color',[0.1 0.7 0.2],'LineWidth',1.0);

    tiempo_S1_todos = pcg_reg.tiempo_picos(pcg_reg.idx_S1);
    for k = 1:length(pares_R_idx)
        t_R  = ecg_reg.tiempo_R(pares_R_idx(k));
        t_S1 = tiempo_S1_todos(pares_S1_idx(k));
        if t_R <= t_lim
            % Flecha de R a S1
            annotation('arrow', ...
                [t_R/t_lim * 0.78 + 0.11, t_S1/t_lim * 0.78 + 0.11], ...
                [0.72, 0.72], 'Color','m','LineWidth',1.5,'HeadLength',6);
        end
    end

    % Marcar picos R y S1 en el gráfico
    mask_R_p = ecg_reg.tiempo_R <= t_lim;
    plot(ecg_reg.tiempo_R(mask_R_p), ones(sum(mask_R_p),1)*0.95, ...
        'v','Color','y','MarkerFaceColor','y','MarkerSize',7);
    mask_S1_p = tiempo_S1_todos <= t_lim;
    plot(tiempo_S1_todos(mask_S1_p), ones(sum(mask_S1_p),1)*-0.95, ...
        '^','Color','c','MarkerFaceColor','c','MarkerSize',7);

    xlabel('Tiempo (s)'); ylabel('Amplitud norm.');
    title('Señales sincronizadas — Picos R (▼) y eventos S1 (▲)');
    legend('ECG filtrado','PCG filtrado','Picos R','S1', ...
        'Location','northeast');
    xlim([0 t_lim]); ylim([-1.2 1.2]); grid on;

    subplot(2,1,2);
    % Retardo R-S1 por latido
    stem(1:length(retardos_RS1), retardos_RS1, ...
        'filled','Color','m','MarkerSize',6,'LineWidth',1.5);
    hold on;
    yline(retardo_promedio, 'r--', 'LineWidth', 2);
    yline(20,  'k:', 'LineWidth', 1);
    yline(100, 'k:', 'LineWidth', 1);

    % Zona fisiológica sombreada
    patch([0.5, length(retardos_RS1)+0.5, length(retardos_RS1)+0.5, 0.5], ...
          [20, 20, 100, 100], [0.9 1.0 0.9], 'FaceAlpha', 0.3, ...
          'EdgeColor', 'none');

    xlabel('Ciclo cardíaco (#)'); ylabel('Retardo R-S1 (ms)');
    title(sprintf('Retardo R-S1 por ciclo — Promedio: %.1f ± %.1f ms', ...
        retardo_promedio, retardo_std));
    legend(sprintf('Retardo por latido'), ...
           sprintf('Promedio (%.1f ms)', retardo_promedio), ...
           'Límite inf. 20 ms', 'Límite sup. 100 ms', ...
           'Zona fisiológica', 'Location','best');
    ylim([0, max(150, max(retardos_RS1)*1.2)]);
    xlim([0.5, length(retardos_RS1)+0.5]);
    grid on;

    sgtitle('Retardo Electromecánico R-S1 — Modalidad A (Sincronizado)', ...
        'FontSize',12,'FontWeight','bold');
end

%% =========================================================
%  SECCIÓN 9: COMPARACIÓN DE FRECUENCIA CARDÍACA
% ==========================================================

FC_ecg = ecg_reg.FC_promedio;
FC_pcg = pcg_reg.FC_pcg_promedio;

if ~isnan(FC_ecg) && ~isnan(FC_pcg)
    diferencia_FC = abs(FC_ecg - FC_pcg);
    concordancia  = 100 - (diferencia_FC / FC_ecg * 100);

    fprintf('=== COMPARACIÓN DE FRECUENCIA CARDÍACA ===\n');
    fprintf('FC estimada por ECG  : %.1f BPM\n', FC_ecg);
    fprintf('FC estimada por PCG  : %.1f BPM\n', FC_pcg);
    fprintf('Diferencia absoluta  : %.1f BPM\n', diferencia_FC);
    fprintf('Concordancia         : %.1f%%\n\n', concordancia);

    figure('Name','Comparación de FC: ECG vs PCG','NumberTitle','off');

    subplot(1,2,1);
    bar_vals = [FC_ecg, FC_pcg];
    bar_std  = [ecg_reg.FC_std, pcg_reg.FC_std];
    b = bar(bar_vals, 0.5, 'FaceColor','flat');
    b.CData(1,:) = [0.2 0.4 0.8];
    b.CData(2,:) = [0.1 0.7 0.2];
    hold on;
    errorbar(1:2, bar_vals, bar_std, 'k.','LineWidth',1.5);
    xticks([1 2]);
    xticklabels({'ECG (RR)', 'PCG (S1-S1)'});
    ylabel('Frecuencia cardíaca (BPM)');
    title('FC Promedio: ECG vs PCG');
    yline(60,  'r--','60 BPM', 'LineWidth',1);
    yline(100, 'r--','100 BPM','LineWidth',1);
    ylim([0 120]); grid on;

    subplot(1,2,2);
    if ~isempty(ecg_reg.intervalos_RR)
        FC_ecg_inst = 60 ./ ecg_reg.intervalos_RR;
        plot(ecg_reg.tiempo_R(2:end), FC_ecg_inst, ...
            'b.-','LineWidth',1,'MarkerSize',10); hold on;
    end
    if ~isempty(pcg_reg.intervalos_S1S1)
        FC_pcg_inst = 60 ./ pcg_reg.intervalos_S1S1;
        plot(pcg_reg.tiempo_picos(pcg_reg.idx_S1(2:end)), FC_pcg_inst, ...
            'g.-','LineWidth',1,'MarkerSize',10);
    end
    xlabel('Tiempo (s)'); ylabel('FC instantánea (BPM)');
    title('Variabilidad de FC en el Tiempo');
    legend('ECG (RR)','PCG (S1-S1)','Location','best');
    yline(60,'r--'); yline(100,'r--');
    grid on;

else
    fprintf('ADVERTENCIA: No se puede comparar FC (datos insuficientes).\n\n');
    diferencia_FC = NaN; concordancia = NaN;
end

%% =========================================================
%  SECCIÓN 10: TABLA RESUMEN COMPARATIVA
% ==========================================================

fprintf('=== TABLA RESUMEN COMPARATIVA ECG vs PCG — MODALIDAD A ===\n');
fprintf('%-38s %-15s %-15s\n', 'Parámetro', 'ECG', 'PCG');
fprintf('%s\n', repmat('-',1,68));
fprintf('%-38s %-15s %-15s\n',  'Señal',                'Eléctrica',   'Acústica');
fprintf('%-38s %-15d %-15d\n',  'Frec. muestreo (Hz)',  ecg_reg.fs,    pcg_reg.fs);
fprintf('%-38s %-15.1f %-15.1f\n','Duración (s)',        ecg_reg.duracion_s, pcg_reg.duracion_s);
fprintf('%-38s %-15s %-15s\n',  'Rango filtrado',        '0.5-40 Hz',   '20-150 Hz');
fprintf('%-38s %-15.1f %-15.1f\n','FC promedio (BPM)',   FC_ecg,        FC_pcg);
fprintf('%-38s %-15.1f %-15.1f\n','FC desv. estándar',   ecg_reg.FC_std, pcg_reg.FC_std);
fprintf('%-38s %-15.3f %-15.3f\n','Periodo promedio (s)',ecg_reg.RR_promedio, ...
    mean(pcg_reg.intervalos_S1S1));
fprintf('%-38s %-15.6f %-15.8f\n','RMS señal',           ecg_reg.RMS_senal, pcg_reg.RMS_pcg);
fprintf('%-38s %-15.2f %-15.2f\n','Frec. mediana (Hz)',  ecg_reg.frec_mediana, pcg_reg.frec_mediana_pcg);
fprintf('%-38s %-15d %-15d\n',  'Eventos detectados',    length(ecg_reg.picos_R), length(pcg_reg.picos_pcg));
fprintf('%s\n', repmat('-',1,68));
fprintf('%-38s %-15.1f\n', 'Diferencia FC ECG-PCG (BPM)',  diferencia_FC);
fprintf('%-38s %-14.1f%%\n','Concordancia de FC',           concordancia);
fprintf('%-38s %-15.1f\n', 'Retardo R-S1 promedio (ms)',   retardo_promedio);
fprintf('%-38s %-15.1f\n', 'Retardo R-S1 desv. std (ms)',  retardo_std);
fprintf('%-38s %-15d\n',   'Pares R-S1 analizados',        length(retardos_RS1));
fprintf('\n');

%% =========================================================
%  SECCIÓN 11: DISCUSIÓN DE CONCORDANCIA Y RETARDO R-S1
% ==========================================================

fprintf('=== DISCUSIÓN (Modalidad A) ===\n\n');

if ~isnan(concordancia)
    if concordancia >= 90
        fprintf('[CONCORDANCIA ALTA] Diferencia: %.1f BPM (%.1f%%).\n', ...
            diferencia_FC, concordancia);
        fprintf('Las dos modalidades de registro producen estimaciones\n');
        fprintf('de FC consistentes entre sí.\n\n');
    elseif concordancia >= 75
        fprintf('[CONCORDANCIA MODERADA] Diferencia: %.1f BPM (%.1f%%).\n', ...
            diferencia_FC, concordancia);
        fprintf('Posibles causas: detección imperfecta de S1 o ruido acústico.\n\n');
    else
        fprintf('[CONCORDANCIA BAJA] Diferencia: %.1f BPM (%.1f%%).\n', ...
            diferencia_FC, concordancia);
        fprintf('Revisar calidad del sensor acústico o umbral del Código 6.\n\n');
    end
end

fprintf('RETARDO R-S1 (exclusivo de Modalidad A):\n');
if ~isnan(retardo_promedio)
    fprintf('  Promedio: %.1f ms | Rango fisiológico esperado: 20-100 ms.\n', ...
        retardo_promedio);
    fprintf('  Este retardo representa el intervalo entre la despolarización\n');
    fprintf('  ventricular (pico R del ECG) y el cierre de la válvula mitral\n');
    fprintf('  (primer ruido cardíaco S1 del fonocardiograma).\n');
    fprintf('  En Modalidad B este cálculo no es posible por falta de sincronía.\n\n');
else
    fprintf('  No fue posible calcular el retardo R-S1.\n');
    fprintf('  Revise la detección de S1 en el Código 6.\n\n');
end

%% =========================================================
%  SECCIÓN 12: FIGURA RESUMEN FINAL (6 paneles)
% ==========================================================

figure('Name','Resumen Final: ECG vs PCG — Modalidad A', ...
    'NumberTitle','off','Position',[50 50 1400 800]);

subplot(3,2,1);
plot(ecg_reg.tiempo, ecg_norm, 'b','LineWidth',0.8); hold on;
plot(ecg_reg.tiempo_R, ones(size(ecg_reg.tiempo_R))*0.95, ...
    'v','Color','y','MarkerFaceColor','y','MarkerSize',5);
xlabel('Tiempo (s)'); ylabel('Amplitud norm.');
title('ECG Filtrado + Picos R');
xlim([0 min(10, max(ecg_reg.tiempo))]); grid on;

subplot(3,2,2);
plot(pcg_reg.tiempo_pcg, pcg_norm, 'Color',[0.1 0.7 0.2],'LineWidth',0.5); hold on;
if ~isempty(pcg_reg.idx_S1)
    plot(pcg_reg.tiempo_picos(pcg_reg.idx_S1), ...
         pcg_reg.picos_pcg(pcg_reg.idx_S1)*0.95, ...
         'v','Color','c','MarkerFaceColor','c','MarkerSize',5);
end
xlabel('Tiempo (s)'); ylabel('Amplitud norm.');
title('PCG Filtrado + Eventos S1');
xlim([0 min(10, max(pcg_reg.tiempo_pcg))]); grid on;

subplot(3,2,3);
plot(f_ecg(idx_ecg), FFT_ecg(idx_ecg), 'b','LineWidth',0.8);
xlabel('Frecuencia (Hz)'); ylabel('|X(f)|');
title('Espectro FFT - ECG'); xlim([0 50]); grid on;

subplot(3,2,4);
plot(f_pcg(idx_pcg), FFT_pcg(idx_pcg), 'Color',[0.1 0.7 0.2],'LineWidth',0.8);
xlabel('Frecuencia (Hz)'); ylabel('|X(f)|');
title('Espectro FFT - PCG'); xlim([0 200]); grid on;

subplot(3,2,5);
if ~isempty(ecg_reg.intervalos_RR)
    stem(1:length(ecg_reg.intervalos_RR), ecg_reg.intervalos_RR, ...
        'filled','b','MarkerSize',4);
    ylabel('Intervalo RR (s)'); xlabel('Latido');
    title('Intervalos RR - ECG');
    yline(ecg_reg.RR_promedio,'r--','Promedio'); grid on;
end

subplot(3,2,6);
if ~isnan(retardo_promedio) && ~isempty(retardos_RS1)
    stem(1:length(retardos_RS1), retardos_RS1, ...
        'filled','Color','m','MarkerSize',4);
    hold on;
    yline(retardo_promedio,'r--','Promedio','LineWidth',1.5);
    yline(20,'k:'); yline(100,'k:');
    ylabel('Retardo R-S1 (ms)'); xlabel('Ciclo cardíaco');
    title(sprintf('Retardo R-S1 — Prom: %.1f ms', retardo_promedio));
    grid on;
elseif ~isempty(pcg_reg.intervalos_S1S1)
    stem(1:length(pcg_reg.intervalos_S1S1), pcg_reg.intervalos_S1S1, ...
        'filled','Color',[0.1 0.7 0.2],'MarkerSize',4);
    ylabel('Intervalo S1-S1 (s)'); xlabel('Ciclo');
    title('Intervalos S1-S1 - PCG');
    yline(mean(pcg_reg.intervalos_S1S1),'r--','Promedio'); grid on;
end

sgtitle('Resumen Comparativo: ECG vs Fonocardiograma — Modalidad A', ...
    'FontSize',13,'FontWeight','bold');

fprintf('=== COMPARACIÓN ECG-PCG COMPLETADA (MODALIDAD A) ===\n');
fprintf('Figuras generadas:\n');
fprintf('  Fig. 1 — Señales sincronizadas (3 paneles)\n');
fprintf('  Fig. 2 — Ventana 5 s con picos R y S1\n');
fprintf('  Fig. 3 — Comparación espectral FFT\n');
fprintf('  Fig. 4 — Retardo R-S1 por ciclo cardíaco\n');
fprintf('  Fig. 5 — Comparación de FC y variabilidad\n');
fprintf('  Fig. 6 — Resumen final 6 paneles\n\n');
