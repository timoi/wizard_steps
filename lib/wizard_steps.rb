module WizardSteps
  
  # Extensions to ActiveRecord::Base
  module ActiveRecord
    def self.included ( base )
      base.send :extend, ClassMethods
    end
    
    module ClassMethods
      
      # Returns a validation Proc for rails validations things. The validation is 
      # effective on wizard step given as a parameter and after the wizard has completed
      #
      # Usage:
      #   validates_presence_of :some_field, :if => after_wizard_step(:confirmation)
      #
      def after_wizard_step(step)
        Proc.new do |obj|
          obj.wizard_status == step.to_s || obj.wizard_status == '__completed'
        end
      end
       
    end  
  end
  
  
  # Extensions to ActionController::Base
  module ActionController
    def self.included( base )
      base.send :extend, ClassMethods
    end
    
    module ClassMethods
      
      # This method is used to define the actions that belong to the wizard.
      # 
      # Usage:
      #   wizard_steps  [:first_step, 'Title of first step']
      #                 [:second_step, 'Second step']
      #                 [:third_step, 'The final step!!']
      #
      def wizard_steps(*args)
        self.send(:include, InstanceMethods)
        @wizard_steps = args
        before_filter :save_current_wizard_action, :only => args.map{|kv| kv[0]}
      end
      
      
    end
    
    module InstanceMethods
      
      # Prints out the wizard status as a HTML use in your view.
      # TODO: should probably go to some view helper instead of controller
      def wizard_status_bar_for(object, view)
        return '' if wizard_complete?(object) 
        steps = self.class.instance_variable_get(:@wizard_steps)
        tds = []
        completed = true
        percentage = 100/steps.length
        steps.each_with_index do |action_and_title,i|
          active = session[:current_wizard_action] == action_and_title[0].to_s
          completed = false if active
          title = (i+1).to_s+'. '+ action_and_title[1].to_s
          classes = []
          classes << 'completed' if completed
          classes << 'active' if active
          title = view.link_to title, :action => action_and_title[0] if completed
          tds << "<td class=\"#{classes.join}\" style=\"width: #{percentage}%;\">#{title}</td>"
        end
        "<table class=\"wizard_progress\"><tr>#{tds.join}</tr></table>"
      end
      
      def wizard_complete?(object)
        object.wizard_status == '__completed'
      end

      def redirect_to_next_wizard_page(object)
        wizard_actions = self.class.instance_variable_get(:@wizard_steps).map{|kv|kv[0].to_s}
        wizard_page_index = object.wizard_status.nil? ? -1 : wizard_actions.index(previous_wizard_page)
        if wizard_page_index + 1 < wizard_actions.length
          next_action = wizard_actions[wizard_page_index+1]
          object.update_attribute(:wizard_status, next_action)
          redirect_to :id => object.id, :action => next_action
          return true
        else
          object.update_attribute(:wizard_status, '__completed')
          return false
        end
      end
      
      def previous_wizard_page
        session[:current_wizard_action]
      end
      
      def save_current_wizard_action
        session[:current_wizard_action] = action_name
      end
    end
  end
end

ActionController::Base.send(:include, WizardSteps::ActionController)
ActiveRecord::Base.send(:include, WizardSteps::ActiveRecord)