import { motion } from "framer-motion";
import { Link } from "wouter";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { Button } from "@/components/ui/button";
import { CheckCircle2, Activity, Database, Lock, BarChart3 } from "lucide-react";

export default function Platform() {
  const features = [
    {
      icon: <Activity className="h-6 w-6 text-primary" />,
      title: "Real-time Visibility",
      description: "Gain immediate oversight into all operational vectors with comprehensive dashboards and metrics."
    },
    {
      icon: <Lock className="h-6 w-6 text-primary" />,
      title: "Rigorous Governance",
      description: "Enforce compliance and standard operating procedures automatically across all departments."
    },
    {
      icon: <Database className="h-6 w-6 text-primary" />,
      title: "Structured Operations",
      description: "Standardize workflows and communication protocols to eliminate redundancy and operational silos."
    },
    {
      icon: <BarChart3 className="h-6 w-6 text-primary" />,
      title: "Decision Support",
      description: "Leverage advanced analytics to make informed, proactive decisions before issues escalate."
    }
  ];

  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />

      <section className="relative pt-32 pb-20 md:pt-48 md:pb-32 bg-primary overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-primary to-primary/80 z-10" />
        <div className="absolute inset-0 bg-[url('https://images.unsplash.com/photo-1542296332-2e4473faf563?q=80&w=2070&auto=format&fit=crop')] bg-cover bg-center opacity-10 mix-blend-overlay z-0" />
        
        <div className="container mx-auto px-4 md:px-6 relative z-20">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="max-w-3xl"
          >
            <div className="inline-block px-3 py-1 rounded-full bg-secondary/20 border border-secondary/30 text-secondary-foreground text-sm font-bold tracking-wider uppercase mb-6">
              Enterprise Solution
            </div>
            <h1 className="text-4xl md:text-6xl font-bold text-white mb-6 leading-tight">
              Aviation Matrix Operations Platform
            </h1>
            <p className="text-xl text-white/80 leading-relaxed mb-8">
              An operational intelligence platform designed to help aviation organizations structure operations, govern data, improve visibility, and support decision making.
            </p>
            <Link href="/contact">
              <Button size="lg" className="bg-secondary text-white hover:bg-secondary/90">
                Request Platform Preview
              </Button>
            </Link>
          </motion.div>
        </div>
      </section>

      <section className="py-24 bg-background">
        <div className="container mx-auto px-4 md:px-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
            <motion.div
              initial={{ opacity: 0, x: -30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            >
              <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-6">Command Your Operations</h2>
              <div className="h-1 w-20 bg-secondary mb-8"></div>
              
              <div className="space-y-6 text-lg text-muted-foreground leading-relaxed mb-8">
                <p>
                  Aviation organizations generate massive amounts of data daily, yet much of it remains siloed or unactionable. The Aviation Matrix Platform transforms fragmented data into unified operational intelligence.
                </p>
                <p>
                  Designed with the exacting standards of an airline operations center, the platform serves as the digital nervous system for your enterprise. It aligns teams, surfaces critical metrics, and provides the framework necessary for scalable, secure operations.
                </p>
              </div>

              <ul className="space-y-4">
                {[
                  "Centralized data architecture",
                  "Automated compliance tracking",
                  "Cross-departmental communication workflows",
                  "Predictive bottleneck analysis"
                ].map((item, i) => (
                  <li key={i} className="flex items-center gap-3">
                    <CheckCircle2 className="h-5 w-5 text-secondary shrink-0" />
                    <span className="font-medium text-foreground">{item}</span>
                  </li>
                ))}
              </ul>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
              className="bg-card border border-border shadow-2xl rounded-2xl p-8"
            >
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-8">
                {features.map((feature, i) => (
                  <div key={i} className="space-y-4">
                    <div className="h-12 w-12 rounded-lg bg-primary/5 flex items-center justify-center">
                      {feature.icon}
                    </div>
                    <h4 className="font-bold text-lg">{feature.title}</h4>
                    <p className="text-sm text-muted-foreground">{feature.description}</p>
                  </div>
                ))}
              </div>
            </motion.div>
          </div>
        </div>
      </section>

      <section className="py-24 bg-muted/30 border-t border-border">
        <div className="container mx-auto px-4 md:px-6 text-center max-w-4xl">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-6">Ready to upgrade your operational intelligence?</h2>
          <p className="text-xl text-muted-foreground mb-10">
            Join the organizations already using Aviation Matrix Platform to drive efficiency and safety.
          </p>
          <Link href="/contact">
            <Button size="lg" className="bg-primary text-white hover:bg-primary/90 h-14 px-8 text-lg">
              Contact Our Sales Team
            </Button>
          </Link>
        </div>
      </section>

      <Footer />
    </div>
  );
}
