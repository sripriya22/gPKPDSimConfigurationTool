classdef Controller < appFramework.AbstractController
    % Controller - Controller for gPKPD Sim Configuration Tool
    %
    % This controller manages a PKPD.Analysis object as its root model.
    % The Analysis object can be:
    %   - Loaded from a .mat file (existing analysis)
    %   - Created new by importing a model from a .sbproj file
    %
    % UI changes are applied directly to the Analysis object, keeping it
    % in sync. Save simply persists the current Analysis object to a file.
    %
    % See also: appFramework.AbstractController, PKPD.Analysis
    
    properties (SetAccess = private)
        SourceFilePath (1,1) string = ""
    end
    
    methods (Access = protected)
        function path = getProjectionMapsPath(obj) %#ok<MANU>
            % Return path to projection map JSON files for this app
            path = fullfile(fileparts(mfilename('fullpath')), ...
                '..', '..', '..', 'shared', 'model-projection');
        end
    end
    
    methods
        function obj = Controller(htmlComponent)
            % Controller - Construct the controller
            %
            % Syntax:
            %   ctrl = Controller()           % Standalone mode
            %   ctrl = Controller(htmlComp)   % Connected to UI
            
            arguments
                htmlComponent matlab.ui.control.HTML {mustBeScalarOrEmpty} = matlab.ui.control.HTML.empty
            end
            
            obj@appFramework.AbstractController(htmlComponent);
        end
    end
    
    % Public CLI API - thin wrappers around handlers
    methods (Access = public)
        function analysis = loadFromAnalysisFile(obj, filePath)
            % loadFromAnalysisFile - Load Analysis object from .mat file
            %
            % Inputs:
            %   filePath - (Optional) Path to .mat file. Opens file browser if missing.
            %
            % Returns:
            %   analysis - The loaded PKPD.Analysis object
            
            arguments
                obj
                filePath (1,1) string = missing
            end
            
            obj.handleLoadFromAnalysisFile(FilePath=filePath);
            analysis = obj.RootObject;
        end
        
        function analysis = loadFromProject(obj, filePath, modelName)
            % loadFromProject - Create new Analysis from SimBiology project
            %
            % Inputs:
            %   filePath  - (Optional) Path to .sbproj file. Opens file browser if missing.
            %   modelName - (Optional) Name of model to import. Auto-detected if project has single model.
            %
            % Returns:
            %   analysis - The created PKPD.Analysis object
            
            arguments
                obj
                filePath (1,1) string = missing
                modelName (1,1) string = missing
            end
            
            obj.handleLoadFromProject(FilePath=filePath, ModelName=modelName);
            analysis = obj.RootObject;
        end
        
        function save(obj, filePath)
            % save - Save Analysis object to .mat file
            %
            % Inputs:
            %   filePath - (Optional) Path to save file. Opens file browser if missing.
            
            arguments
                obj
                filePath (1,1) string = missing
            end
            
            obj.handleSave(FilePath=filePath);
        end
        
        function modelNames = queryProjectForModels(obj, filePath)
            % queryProjectForModels - Get list of models in a .sbproj file
            %
            % Inputs:
            %   filePath - (Optional) Path to .sbproj file. Opens file browser if missing.
            %
            % Returns:
            %   modelNames - String array of model names in the project
            
            arguments
                obj %#ok<INUSA>
                filePath (1,1) string = missing
            end
            
            results = obj.handleQueryProjectForModels(FilePath=filePath);
            modelNames = results.ModelNames;
        end
    end
    
    % Handler methods - core implementation with NVP inputs
    methods (Access = {?appFramework.AbstractController})
        function results = handleLoadFromAnalysisFile(obj, inputs)
            % Handler for loading Analysis from .mat file
            
            arguments
                obj
                inputs.FilePath (1,1) string = missing
            end
            
            if ismissing(inputs.FilePath)
                [file, path] = uigetfile({'*.mat', 'MAT Files (*.mat)'}, ...
                    'Select Analysis File');
                if isequal(file, 0)
                    error('gPKPDSimConfigurationTool:Cancelled', 'File selection cancelled');
                end
                inputs.FilePath = fullfile(path, file);
            end
            
            analysis = obj.loadAnalysisFromMatfile(inputs.FilePath);
            obj.setRootObject(analysis);
            obj.SourceFilePath = inputs.FilePath;
            
            results = struct('FilePath', inputs.FilePath);
        end
        
        function results = handleLoadFromProject(obj, inputs)
            % Handler for creating Analysis from .sbproj file
            
            arguments
                obj
                inputs.FilePath (1,1) string = missing
                inputs.ModelName (1,1) string = missing
            end
            
            if ismissing(inputs.FilePath)
                [file, path] = uigetfile({'*.sbproj', 'SimBiology Project (*.sbproj)'}, ...
                    'Select SimBiology Project');
                if isequal(file, 0)
                    error('gPKPDSimConfigurationTool:Cancelled', 'File selection cancelled');
                end
                inputs.FilePath = fullfile(path, file);
            end
            
            if ismissing(inputs.ModelName)
                modelNames = obj.getModelNamesFromProject(inputs.FilePath);
                if numel(modelNames) == 1
                    inputs.ModelName = modelNames(1);
                else
                    error('gPKPDSimConfigurationTool:MultipleModels', ...
                        'Project contains %d models. Please specify ModelName.', numel(modelNames));
                end
            end
            
            analysis = PKPD.Analysis;
            analysis.importModel(char(inputs.FilePath), char(inputs.ModelName));
            
            obj.setRootObject(analysis);
            obj.SourceFilePath = inputs.FilePath;
            
            results = struct('FilePath', inputs.FilePath, 'ModelName', inputs.ModelName);
        end
        
        function results = handleSave(obj, inputs)
            % Handler for saving Analysis to .mat file
            
            arguments
                obj
                inputs.FilePath (1,1) string = missing
            end
            
            if ismissing(inputs.FilePath)
                [file, path] = uiputfile({'*.mat', 'MAT Files (*.mat)'}, ...
                    'Save Analysis File');
                if isequal(file, 0)
                    error('gPKPDSimConfigurationTool:Cancelled', 'File selection cancelled');
                end
                inputs.FilePath = fullfile(path, file);
            end
            
            if ~endsWith(inputs.FilePath, ".mat")
                inputs.FilePath = inputs.FilePath + ".mat";
            end
            
            obj.validateRootObject();
            
            obj.prepareAnalysisForSave();
            
            Analysis = obj.RootObject; %#ok<PROPLC>
            save(inputs.FilePath, 'Analysis');
            
            obj.SourceFilePath = inputs.FilePath;
            
            results = struct('FilePath', inputs.FilePath);
        end
        
        function results = handleQueryProjectForModels(~, inputs)
            % Handler for querying models in a .sbproj file
            
            arguments
                ~
                inputs.FilePath (1,1) string = missing
            end
            
            if ismissing(inputs.FilePath)
                [file, path] = uigetfile({'*.sbproj', 'SimBiology Project (*.sbproj)'}, ...
                    'Select SimBiology Project');
                if isequal(file, 0)
                    error('gPKPDSimConfigurationTool:Cancelled', 'File selection cancelled');
                end
                inputs.FilePath = fullfile(path, file);
            end
            
            projStruct = sbioloadproject(inputs.FilePath);
            varNames = string(fieldnames(projStruct))';
            modelNames = string.empty;
            
            for varName = varNames
                if isa(projStruct.(varName), 'SimBiology.Model')
                    modelNames(end+1) = projStruct.(varName).Name; %#ok<AGROW>
                end
            end
            
            results = struct('FilePath', inputs.FilePath, 'ModelNames', modelNames);
        end
    end
    
    methods (Access = private)
        function modelNames = getModelNamesFromProject(~, filePath)
            % Get model names from a SimBiology project file
            
            projStruct = sbioloadproject(filePath);
            varNames = string(fieldnames(projStruct))';
            modelNames = string.empty;
            
            for varName = varNames
                if isa(projStruct.(varName), 'SimBiology.Model')
                    modelNames(end+1) = projStruct.(varName).Name; %#ok<AGROW>
                end
            end
        end
        
        function analysis = loadAnalysisFromMatfile(obj, filePath)
            % Load PKPD.Analysis object from .mat file
            
            arguments
                obj
                filePath (1,1) string
            end
            
            if ~isfile(filePath)
                error('gPKPDSimConfigurationTool:FileNotFound', ...
                    'File not found: %s', filePath);
            end
            
            matData = load(filePath);
            
            if isfield(matData, 'Analysis') && isa(matData.Analysis, 'PKPD.Analysis')
                analysis = matData.Analysis;
                obj.remapModelComponents(analysis);
            else
                error('gPKPDSimConfigurationTool:InvalidAnalysisFile', ...
                    'File does not contain a valid PKPD.Analysis object');
            end
        end
        
        function remapModelComponents(~, analysis)
            % Remap SelectedSpecies, SelectedDoses, SelectedVariants to current ModelObj
            % This is necessary because loaded Analysis objects reference old model instances
            
            if isempty(analysis.ModelObj)
                return;
            end
            
            % Models loaded from before 19b (UDD models instead of MCOS models) will reload
            % references to model components as orphaned objects instead of pointing to the
            % same handle. Update these references (species and doses) to point to the current
            % model components.
            tfUDDModel = isempty(analysis.SelectedSpecies(1).ParentModel);
            if tfUDDModel
                allSpecies = analysis.ModelObj.Species;
                remappedSpecies = SimBiology.Species.empty;                
                for i = numel(analysis.SelectedSpecies):-1:1
                    oldSpecies = analysis.SelectedSpecies(i);
                    newSpecies = sbioselect(allSpecies, 'UUID', oldSpecies.UUID);
                    remappedSpecies(end+1) = newSpecies;
                end                
                analysis.SelectedSpecies = remappedSpecies;
            
                allDoses = getdose(analysis.ModelObj);
                remappedDoses = SimBiology.Dose.empty;                
                for i = numel(analysis.SelectedDoses):-1:1
                    oldDose = analysis.SelectedDoses(i);
                    newDose = sbioselect(allDoses, 'UUID', oldDose.UUID);
                    remappedDoses(end+1) = newDose;
                end                
                analysis.SelectedDoses = remappedDoses;
            end
            
            % Remap SelectedVariants using UUID
            if ~isempty(analysis.SelectedVariants)
                allVariants = getvariant(analysis.ModelObj);
                remappedVariants = SimBiology.Variant.empty;
                
                for i = 1:numel(analysis.SelectedVariants)
                    oldVariant = analysis.SelectedVariants(i);
                    newVariant = sbioselect(allVariants, 'UUID', oldVariant.UUID);
                    if ~isempty(newVariant)
                        remappedVariants(end+1) = newVariant; %#ok<AGROW>
                    end
                end
                
                analysis.SelectedVariants = remappedVariants;
            end
        end
        
        function prepareAnalysisForSave(obj)
            % Prepare Analysis object for saving by setting required properties
            % This ensures the saved Analysis is compatible with gPKPDSim
            
            analysis = obj.RootObject;
            
            % Update StatesToLog to log all selected species
            analysis.ModelObj.getconfigset().RuntimeOptions.StatesToLog = ...
                analysis.SelectedSpecies;
            
            % Set up PlotSpeciesTable
            numSelectedSpecies = numel(analysis.SelectedSpecies);
            analysis.PlotSpeciesTable = cell(numSelectedSpecies, 3);
            names = {analysis.SelectedSpecies.PartiallyQualifiedName}';
            analysis.PlotSpeciesTable(:, 2) = names;
            analysis.PlotSpeciesTable(:, 3) = names;
            analysis.updateSpeciesLineStyles();
            
            % Create SimulationPlotSettings
            % Must create temporary axes to create PlotSettings object
            f = figure('Visible', 'off');
            ax = axes(f);
            ps = PKPD.PlotSettings(ax);
            delete(f);
            
            analysis.SimulationPlotSettings = getSummary(ps);
            analysis.SimulationPlotSettings.Title = 'Plot 1';
            analysis.SimulationPlotSettings.XLabel = 'Time';
            analysis.SimulationPlotSettings.YLabel = 'States';
            
            % Set ColorMap
            analysis.ColorMap1 = parula;
        end
    end
end
