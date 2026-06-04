%% =========================================================
%  CÓDIGO 2/4 UNIFICADO - ADQUISICIÓN SIMULTÁNEA ECG + PCG
%  Procesamiento de Señales II - Universidad del Magdalena
%  Modalidad A: Adquisición sincronizada
%
%  REEMPLAZA los Códigos 2 (ECG) y 4 (PCG) originales.
%  El firmware del ESP32 envía AMBAS señales en cada línea:
%       ecg_raw,pcg_raw   (enteros ADC 0-4095, 1000 Hz)
%
%  SALIDA:
%    señal_ecg.mat → tiempo, amplitud, fs  (fs = 1000 Hz)
%    señal_pcg.mat → tiempo, amplitud, fs  (fs = 1000 Hz)
%    Ambas señales tienen el MISMO vector de tiempo → sincronizadas.
%    Formato idéntico al esperado por Códigos 5 y 6.
%
%  FLUJO:
%    1. Ejecutar este script.
%    2. Botón "Iniciar grabación" → envía 'S' al ESP32.
%    3. Ambas señales se visualizan en tiempo real.
%    4. Botón "Detener y guardar" → guarda los dos .mat y resetea.
% ==========================================================

clear; clc; close all;

%% --- CONFIGURACIÓN ---
puerto         = "COM3";   % <-- Ajustar según puerto del PC
baudios        = 115200;
fs             = 1000;     % Hz — igual para ECG y PCG (sincronización)
ventanaVisible = 8;        % Segundos visibles en pantalla

%% --- INICIALIZACIÓN SERIAL ---
try
    s = serialport(puerto, baudios);
    configureTerminator(s, "LF");
    fprintf("Puerto %s abierto correctamente.\n", puerto);
catch
    error("No se pudo abrir el puerto %s. Revisa la conexión.", puerto);
end

%% =========================================================
%  INTERFAZ GRÁFICA
% ==========================================================
fig = uifigure("Name", "Adquisición Simultánea ECG + PCG — Modalidad A", ...
    "Position", [50 60 1150 600]);
fig.UserData.grabar = false;

% Título
uilabel(fig, 'Position', [0 565 1150 28], ...
    'Text', 'ADQUISICIÓN SIMULTÁNEA  |  ECG + FONOCARDIOGRAMA  |  fs = 1000 Hz  |  Modalidad A', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold', ...
    'FontColor', [0.15 0.15 0.15]);

% ── Panel ECG ──────────────────────────────────────────────
pnlECG = uipanel(fig, 'Position', [15 105 545 455], ...
    'Title', ' ECG — AD8232  |  fs = 1000 Hz', ...
    'FontWeight', 'bold', 'FontSize', 10, ...
    'BackgroundColor', [0.06 0.06 0.06], 'ForegroundColor', 'cyan');

axECG = uiaxes(pnlECG, 'Position', [20 70 500 340], ...
    'BackgroundColor', 'k', 'XColor', 'cyan', 'YColor', 'cyan');
grid(axECG, 'off'); hold(axECG, 'on');
hECG = plot(axECG, NaN, NaN, 'Color', 'cyan', 'LineWidth', 1.2);
title(axECG, "ECG en tiempo real");
xlabel(axECG, "Tiempo (s)"); ylabel(axECG, "Amplitud (V)");
ylim(axECG, [1.0 2.2]);

lblECG = uilabel(pnlECG, 'Position', [100 30 340 22], ...
    'Text', 'ECG: en espera', 'HorizontalAlignment', 'center', ...
    'FontColor', [0.5 0.5 0.5], 'BackgroundColor', [0.06 0.06 0.06]);

% ── Panel PCG ──────────────────────────────────────────────
pnlPCG = uipanel(fig, 'Position', [590 105 545 455], ...
    'Title', ' PCG — Micrófono Electret  |  fs = 1000 Hz', ...
    'FontWeight', 'bold', 'FontSize', 10, ...
    'BackgroundColor', [0.04 0.08 0.04], 'ForegroundColor', [0.2 0.9 0.4]);

axPCG = uiaxes(pnlPCG, 'Position', [20 70 500 340], ...
    'BackgroundColor', 'k', 'XColor', [0.2 0.9 0.4], 'YColor', [0.2 0.9 0.4]);
grid(axPCG, 'off'); hold(axPCG, 'on');
hPCG = plot(axPCG, NaN, NaN, 'Color', [0.2 0.9 0.4], 'LineWidth', 1.0);
title(axPCG, "PCG en tiempo real  (S1/S2)");
xlabel(axPCG, "Tiempo (s)"); ylabel(axPCG, "Amplitud (V)");
ylim(axPCG, [1.0 2.2]);

lblPCG = uilabel(pnlPCG, 'Position', [100 30 340 22], ...
    'Text', 'PCG: en espera', 'HorizontalAlignment', 'center', ...
    'FontColor', [0.5 0.5 0.5], 'BackgroundColor', [0.04 0.08 0.04]);

% ── Botón y barra inferior ────────────────────────────────
btn = uibutton(fig, "push", ...
    "Text", "▶  Iniciar grabación simultánea", ...
    "Position", [425 62 300 36], ...
    "FontSize", 11, "FontWeight", "bold", ...
    "ButtonPushedFcn", @(src,~) toggleGrabacion(src, lblECG, lblPCG, fig, s));

uilabel(fig, 'Position', [15 5 1120 52], ...
    'Text', sprintf(['MODALIDAD A — Adquisición simultánea sincronizada\n' ...
        'Ambas señales comparten el mismo vector de tiempo. ' ...
        'señal_ecg.mat y señal_pcg.mat quedarán listos para los Códigos 5 y 6.']), ...
    'HorizontalAlignment', 'left', 'FontSize', 9, ...
    'FontColor', [0.4 0.4 0.4], 'VerticalAlignment', 'top');

%% =========================================================
%  BUFFERS
% ==========================================================
t_inicio  = [];
tiempo    = [];    % Vector de tiempo compartido
amp_ecg   = [];
amp_pcg   = [];
grabando_ant = false;

%% =========================================================
%  BUCLE PRINCIPAL
% ==========================================================
while ishandle(fig)

    %% 1. LECTURA SERIAL
    while s.NumBytesAvailable > 0
        linea = readline(s);

        % Parsear formato "ecg_raw,pcg_raw"
        partes = strsplit(strtrim(linea), ',');
        if length(partes) ~= 2, continue; end

        ecg_raw = str2double(partes{1});
        pcg_raw = str2double(partes{2});

        if isnan(ecg_raw) || isnan(pcg_raw), continue; end

        if fig.UserData.grabar
            if isempty(t_inicio), t_inicio = tic; end
            t_actual = toc(t_inicio);

            % ECG: descartar muestra si lead-off (ecg_raw == 0)
            % pero mantener la marca de tiempo para no romper la
            % sincronía — se guarda NaN para interpolación posterior
            if ecg_raw == 0
                amp_ecg(end+1) = NaN;
            else
                amp_ecg(end+1) = (ecg_raw * 3.3) / 4095;
            end

            % PCG: sin filtro lead-off
            amp_pcg(end+1) = (pcg_raw * 3.3) / 4095;

            % Tiempo compartido (misma muestra = mismo instante)
            tiempo(end+1) = t_actual;
        end
    end

    %% 2. ACTUALIZACIÓN GRÁFICA ECG
    if ~isempty(tiempo)
        t_now = tiempo(end);
        t_min = max(0, t_now - ventanaVisible);
        mask  = tiempo >= t_min;

        ecg_vis = amp_ecg(mask);
        % Reemplazar NaN por el último valor válido para la gráfica
        for k = 2:length(ecg_vis)
            if isnan(ecg_vis(k)), ecg_vis(k) = ecg_vis(k-1); end
        end
        set(hECG, 'XData', tiempo(mask), 'YData', ecg_vis);
        xlim(axECG, [t_min, max(ventanaVisible, t_now)]);

        %% 3. ACTUALIZACIÓN GRÁFICA PCG
        pcg_vis = amp_pcg(mask);
        set(hPCG, 'XData', tiempo(mask), 'YData', pcg_vis);
        xlim(axPCG, [t_min, max(ventanaVisible, t_now)]);

        % Autoajuste ylim PCG
        centro = mean(pcg_vis, 'omitnan');
        rango  = max(abs(pcg_vis - centro)) * 1.5;
        if rango > 0.01
            ylim(axPCG, [centro - rango, centro + rango]);
        end
    end

    %% 4. GUARDADO AL DETENER
    if ~fig.UserData.grabar && grabando_ant && ~isempty(tiempo)

        % ── Interpolar NaN en ECG (muestras lead-off) ──────
        nan_idx = isnan(amp_ecg);
        if any(~nan_idx)
            amp_ecg(nan_idx) = interp1( ...
                tiempo(~nan_idx), amp_ecg(~nan_idx), ...
                tiempo(nan_idx), 'linear', 'extrap');
        end

        % ── Centrar PCG en cero (quitar offset DC del ADC) ─
        amp_pcg = amp_pcg - mean(amp_pcg, 'omitnan');

        % ── Guardar señal_ecg.mat ───────────────────────────
        tiempo_ecg   = tiempo';
        amplitud_ecg = amp_ecg';
        tiempo   = tiempo_ecg;   %#ok<NASGU>
        amplitud = amplitud_ecg; %#ok<NASGU>
        save("señal_ecg.mat", "tiempo", "amplitud", "fs");

        % Respaldo con fecha
        nombre_ecg = "ecg_simultaneo_" + datestr(now, 'yyyymmdd_HHMMSS');
        ECG_Data = struct('Tiempo', tiempo_ecg, 'Voltaje', amplitud_ecg);
        save(nombre_ecg + ".mat", "ECG_Data");

        % ── Guardar señal_pcg.mat ───────────────────────────
        tiempo_pcg   = tiempo_ecg;   % Mismo vector — clave de la sincronía
        amplitud_pcg = amp_pcg';
        save("señal_pcg.mat", "tiempo_pcg", "amplitud_pcg", "fs");

        % Respaldo con fecha
        nombre_pcg = "pcg_simultaneo_" + datestr(now, 'yyyymmdd_HHMMSS');
        PCG_Data = struct('Tiempo', tiempo_pcg, 'Voltaje', amplitud_pcg);
        save(nombre_pcg + ".mat", "PCG_Data");

        fprintf("✓ Grabación guardada | Duración: %.1f s | Muestras: %d\n", ...
            max(tiempo_ecg), length(tiempo_ecg));
        fprintf("  → señal_ecg.mat  listo para el Código 5\n");
        fprintf("  → señal_pcg.mat  listo para el Código 6\n");
        fprintf("  → Ambas señales comparten el mismo vector de tiempo\n\n");

        % Limpiar para la siguiente grabación
        tiempo   = [];
        amp_ecg  = [];
        amp_pcg  = [];
        t_inicio = [];
    end

    grabando_ant = fig.UserData.grabar;
    drawnow limitrate;
end

%% --- CIERRE ---
try
    write(s, 'K', "char");
    pause(0.1);
    clear s;
    fprintf("Puerto serial cerrado correctamente.\n");
catch
end

%% =========================================================
%  FUNCIÓN TOGGLE
% ==========================================================
function toggleGrabacion(btnObj, lblECG, lblPCG, figObj, s)
    if ~figObj.UserData.grabar
        write(s, 'S', "char");
        figObj.UserData.grabar = true;
        btnObj.Text            = "■  Detener y guardar";
        btnObj.BackgroundColor = [1 0.55 0.55];
        lblECG.Text            = "ECG: grabando...";
        lblECG.FontColor       = [0.9 0.2 0.2];
        lblPCG.Text            = "PCG: grabando...";
        lblPCG.FontColor       = [0.1 0.7 0.1];
    else
        write(s, 'K', "char");
        figObj.UserData.grabar = false;
        btnObj.Text            = "▶  Iniciar grabación simultánea";
        btnObj.BackgroundColor = [0.96 0.96 0.96];
        lblECG.Text            = "ECG: guardando...";
        lblECG.FontColor       = [0.2 0.6 0.2];
        lblPCG.Text            = "PCG: guardando...";
        lblPCG.FontColor       = [0.2 0.6 0.2];
    end
end
