from lib.common import helpers

class Module:

    def __init__(self, mainMenu, params=[]):

        # metadata info about the module, not modified during runtime
        self.info = {
            # name for the module that will appear in module menus
            'Name': 'Invoke-AppEnum',

            # list of one or more authors for the module
            'Author': ['pasv'],

            # more verbose multi-line description of the module
            'Description': ('Enumerates installed applications through the registry and then continues to enumerate their properties'),

            # True if the module needs to run in the background
            'Background' : False,

            # True if we're saving the output as a file
            'SaveOutput' : True,

            # True if the module needs admin rights to run
            'NeedsAdmin' : False,

            # True if the method doesn't touch disk/is reasonably opsec safe
            'OpsecSafe' : True,
            
            # The minimum PowerShell version needed for the module to run
            'MinPSVersion' : '2',

            # list of any references/other comments
            'Comments': [
                ''
            ]
        }

        # any options needed by the module, settable during runtime
        self.options = {
            # format:
            #   value_name : {description, required, default_value}
            'Agent' : {
                # The 'Agent' option is the only one that MUST be in a module
                'Description'   :   'Agent to grab a screenshot from.',
                'Required'      :   True,
                'Value'         :   ''
            },
            'PEVersion' : {
                'Description'   :   'Recursively enumerate file versions for all exe and dll files in identified InstallPaths',
                'Required'      :   False,
                'Value'         :   ''
            }
            'MACE' : {
                'Description'   :   'Recursively enumerate MACE (Modified-Accessed-Created-Entry) for all exe and dll files in identified InstallPaths',
                'Required'      :   False,
                'Value'         :   '' 
            }
            'IsRunning' : {
                'Description'   :   'Identify if any of the applications enumerated are currently running as processes',
                'Required'      :   False,
                'Value'         :   '' 
            }

        }

        # save off a copy of the mainMenu object to access external functionality
        #   like listeners/agent handlers/etc.
        self.mainMenu = mainMenu

        # During instantiation, any settable option parameters
        #   are passed as an object set to the module and the
        #   options dictionary is automatically set. This is mostly
        #   in case options are passed on the command line
        if params:
            for param in params:
                # parameter format is [Name, Value]
                option, value = param
                if option in self.options:
                    self.options[option]['Value'] = value


    def generate(self):
        
        script = """
function Invoke-AppEnum {
    
}
Invoke-AppEnum"""

        # add any arguments to the end execution of the script
        for option,values in self.options.iteritems():
            if option.lower() != "agent":
                if values['Value'] and values['Value'] != '':
                    if values['Value'].lower() == "true":
                        # if we're just adding a switch
                        script += " -" + str(option)
                    else:
                        script += " -" + str(option) + " " + str(values['Value'])

        return script