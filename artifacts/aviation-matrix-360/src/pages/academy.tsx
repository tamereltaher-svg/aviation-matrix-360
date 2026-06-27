import { motion } from "framer-motion";
import { Link } from "wouter";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { Button } from "@/components/ui/button";
import { BookOpen, Award, Target, Rocket } from "lucide-react";

export default function Academy() {
  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />

      <section className="relative pt-32 pb-20 md:pt-48 md:pb-32 bg-primary overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-primary to-primary/80 z-10" />
        <div className="container mx-auto px-4 md:px-6 relative z-20">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="max-w-3xl"
          >
            <div className="inline-block px-3 py-1 rounded-full bg-secondary/20 border border-secondary/30 text-secondary-foreground text-sm font-bold tracking-wider uppercase mb-6">
              Professional Education
            </div>
            <h1 className="text-4xl md:text-6xl font-bold text-white mb-6 leading-tight">
              Aviation Matrix Academy
            </h1>
            <p className="text-xl text-white/80 leading-relaxed mb-8">
              Elevating the industry through professional aviation education, operational knowledge development, and focused learning programs.
            </p>
            <Link href="/contact">
              <Button size="lg" className="bg-secondary text-white hover:bg-secondary/90">
                Enroll Today
              </Button>
            </Link>
          </motion.div>
        </div>
      </section>

      {/* Professional Aviation Learning Section */}
      <section className="py-24 bg-background">
        <div className="container mx-auto px-4 md:px-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
            <motion.div
              initial={{ opacity: 0, x: -30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            >
              <h2 className="text-sm font-bold text-secondary tracking-widest uppercase mb-3">Section 1</h2>
              <h3 className="text-3xl md:text-4xl font-bold text-foreground mb-6">Professional Aviation Learning</h3>
              <div className="h-1 w-20 bg-secondary mb-8"></div>
              <p className="text-lg text-muted-foreground leading-relaxed mb-8">
                Professional aviation education, operational knowledge development, and industry-focused learning programs for aviation professionals and organizations.
              </p>
              <div className="space-y-6 text-lg text-muted-foreground leading-relaxed">
                <p>
                  Technology alone cannot drive the aviation industry forward; it requires highly skilled professionals who understand the intricate balance of operations, safety, and efficiency.
                </p>
                <p>
                  The Aviation Matrix Academy offers rigorous, industry-aligned curricula designed to bridge the gap between theoretical knowledge and practical operational excellence.
                </p>
              </div>
            </motion.div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <div className="bg-card p-6 rounded-xl border border-border shadow-sm">
                <BookOpen className="h-8 w-8 text-secondary mb-4" />
                <h4 className="font-bold text-lg mb-2">Curriculum</h4>
                <p className="text-sm text-muted-foreground">Comprehensive modules covering modern aviation operations and management.</p>
              </div>
              <div className="bg-card p-6 rounded-xl border border-border shadow-sm">
                <Target className="h-8 w-8 text-secondary mb-4" />
                <h4 className="font-bold text-lg mb-2">Practical Focus</h4>
                <p className="text-sm text-muted-foreground">Scenario-based learning that directly translates to real-world operations.</p>
              </div>
              <div className="bg-card p-6 rounded-xl border border-border shadow-sm">
                <Award className="h-8 w-8 text-secondary mb-4" />
                <h4 className="font-bold text-lg mb-2">Certification</h4>
                <p className="text-sm text-muted-foreground">Industry-recognized credentials that validate operational expertise.</p>
              </div>
              <div className="bg-card p-6 rounded-xl border border-border shadow-sm">
                <Rocket className="h-8 w-8 text-secondary mb-4" />
                <h4 className="font-bold text-lg mb-2">Innovation</h4>
                <p className="text-sm text-muted-foreground">Exposure to emerging technologies and methodologies shaping the future.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Kids Aviation Matrix Section */}
      <section className="py-24 bg-muted/40 border-t border-border">
        <div className="container mx-auto px-4 md:px-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
              className="bg-primary rounded-2xl p-10 text-white order-2 lg:order-1"
            >
              <div className="inline-flex items-center justify-center h-16 w-16 rounded-full bg-white/10 mb-6">
                <Rocket className="h-8 w-8 text-secondary" />
              </div>
              <h3 className="text-2xl font-bold mb-4">Kids Aviation Matrix</h3>
              <div className="h-1 w-16 bg-secondary mb-6"></div>
              <p className="text-white/80 leading-relaxed mb-4">Airports. Aircraft. Operations. Careers.</p>
              <ul className="space-y-3 text-white/70 text-sm">
                {["Aviation and airport fundamentals", "How aircraft work", "Aviation careers exploration", "Operational concepts for young minds"].map((item, i) => (
                  <li key={i} className="flex items-center gap-2">
                    <span className="w-1.5 h-1.5 rounded-full bg-secondary shrink-0" />
                    {item}
                  </li>
                ))}
              </ul>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, x: 30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
              className="order-1 lg:order-2"
            >
              <h2 className="text-sm font-bold text-secondary tracking-widest uppercase mb-3">Section 2</h2>
              <h3 className="text-3xl md:text-4xl font-bold text-foreground mb-6">Kids Aviation Matrix</h3>
              <div className="h-1 w-20 bg-secondary mb-8"></div>
              <p className="text-lg text-muted-foreground leading-relaxed mb-8">
                Kids Aviation Matrix is an aviation education initiative designed to introduce children to aviation, airports, aircraft, operations, and aviation careers through engaging learning experiences.
              </p>
              <p className="text-muted-foreground leading-relaxed mb-10">
                Part of the Aviation Matrix Academy ecosystem, this program ensures that the next generation grows up connected to aviation — not just as passengers, but as future professionals, innovators, and leaders in the industry.
              </p>
              <Link href="/contact">
                <Button size="lg" className="bg-primary text-white hover:bg-primary/90">
                  Explore Kids Program
                </Button>
              </Link>
            </motion.div>
          </div>
        </div>
      </section>

      <Footer />
    </div>
  );
}
